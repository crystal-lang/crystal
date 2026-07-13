require "crystal/dwarf"

struct Exception::CallStack
  @@dwarf_frames : Hash(UInt64, DwarfFrame)?
  @@dwarf_frames_lock = Mutex.new

  # Debug info resolved for a single program counter. A `nil` path means the
  # pc has no line number information.
  # :nodoc:
  record DwarfFrame, path : String?, line : Int32, column : Int32, function : String?

  # Debug info is resolved on demand, only for the program counters of the
  # exception being decoded, and the results are memoized here so repeated
  # exceptions from the same locations don't pay the decoding cost again.
  #
  # The cache must not grow without bound — a long-running process can raise
  # from an unbounded number of distinct locations, and the GC is unlikely to
  # return freed pages to the OS — so it is bounded to this many entries,
  # evicting the least-recently-used pc when full. Crystal hashes preserve
  # insertion order, so the oldest entry is always `first_key` and touching an
  # entry means reinserting it at the end.
  private DWARF_FRAME_CACHE_LIMIT = 1024

  private def decode_backtrace
    CallStack.load_debug_info
    show_full_info = ENV["CRYSTAL_CALLSTACK_FULL_INFO"]? == "1"

    frames = CallStack.resolve_dwarf_frames(@callstack)

    @callstack.compact_map do |ip|
      pc = CallStack.decode_address(ip).to_u64!
      frame = frames[pc]?
      CallStack.format_backtrace_frame(ip, show_full_info,
        frame.try(&.path) || "??",
        frame.try(&.line) || 0,
        frame.try(&.column) || 0,
        frame.try(&.function))
    end
  end

  # Resolves the debug info for every program counter of `callstack`,
  # reading previously seen pcs from the cache and batch-decoding the DWARF
  # sections for the others in a single pass per section.
  protected def self.resolve_dwarf_frames(callstack : Array(Void*)) : Hash(UInt64, DwarfFrame)
    frames = Hash(UInt64, DwarfFrame).new(initial_capacity: callstack.size)
    return frames if ENV["CRYSTAL_LOAD_DEBUG_INFO"]? == "0"

    @@dwarf_frames_lock.synchronize do
      cache = @@dwarf_frames ||= Hash(UInt64, DwarfFrame).new
      missing = nil

      callstack.each do |ip|
        pc = decode_address(ip).to_u64!
        next if frames.has_key?(pc)
        if frame = cache[pc]?
          frames[pc] = frame
          # move it to the most-recently-used position
          cache.delete(pc)
          cache[pc] = frame
        else
          missing ||= Array(UInt64).new(callstack.size)
          missing << pc
          # empty placeholder: reserves the key so duplicate pcs aren't added
          # to `missing` twice; overwritten with the resolved frame below
          frames[pc] = DwarfFrame.new(nil, 0, 0, nil)
        end
      end

      if missing
        missing.sort!
        resolve_missing_dwarf_frames(missing, frames)

        missing.each do |pc|
          # evict the least-recently-used pc when the cache is full
          cache.delete(cache.first_key) if cache.size >= DWARF_FRAME_CACHE_LIMIT
          cache[pc] = frames[pc]
        end
      end
    end

    frames
  end

  # Decodes the debug info for the given sorted pcs, storing a `DwarfFrame`
  # for each of them — negative when the executable has no debug info at all
  # or none for that pc — into `frames`.
  private def self.resolve_missing_dwarf_frames(pcs : Array(UInt64), frames) : Nil
    size = pcs.size
    sorted_pcs = Slice.new(pcs.to_unsafe, size)
    paths = Slice(String?).new(size, nil)
    lines = Slice(Int32).new(size, 0)
    columns = Slice(Int32).new(size, 0)
    functions = Slice(String?).new(size, nil)

    begin
      open_debug_image do |image, base_address|
        base = base_address.to_u64!

        line_strings = image.section?(DEBUG_LINE_STR) do |bytes, _|
          Crystal::DWARF::Strings.new(bytes)
        end

        strings = image.section?(DEBUG_STR) do |bytes, _|
          Crystal::DWARF::Strings.new(bytes)
        end

        begin
          image.section?(DEBUG_LINE) do |bytes, _|
            line_numbers = Crystal::DWARF::LineNumbers.new(IO::Memory.new(bytes), base, strings, line_strings)
            line_numbers.resolve(sorted_pcs) do |index, path, line, column|
              paths[index] = path
              lines[index] = line
              columns[index] = column
            end
          end
        rescue
          # The line number info is invalid, so we'll use what we've got up
          # until this point.
        end

        begin
          resolve_dwarf_function_names(image, base, sorted_pcs, functions, strings, line_strings)
        rescue
          # The function information is invalid, so we'll use what we've got up
          # until this point.
        end
      end
    rescue
      # We can't read the debug info at all so we leave every frame unresolved
    end

    size.times do |i|
      frames[pcs[i]] = DwarfFrame.new(paths[i], lines[i], columns[i], functions[i])
    end
  end

  private def self.resolve_dwarf_function_names(image, base_address : UInt64, pcs, functions, strings, line_strings) : Nil
    remaining = pcs.size

    image.section?(DEBUG_ABBREV) do |abbrev_bytes, _|
      image.section?(DEBUG_INFO) do |bytes, section_offset|
        io = IO::Memory.new(bytes)
        abbrev_io = IO::Memory.new(abbrev_bytes)
        abbrev_offset = -1_i64
        abbreviations = nil

        while io.pos < bytes.size && remaining > 0
          info = Crystal::DWARF::Info.new(io, section_offset)

          offset = info.debug_abbrev_offset.to_i64!
          unless abbreviations && offset == abbrev_offset
            abbrev_io.pos = offset
            abbreviations = Crystal::DWARF::Abbrev.read(abbrev_io)
            abbrev_offset = offset
          end
          info.abbreviations = abbreviations

          info.each_subprogram do |low_pc, high_pc, name_form, name_value|
            low = low_pc &+ base_address
            high = high_pc &+ base_address
            next unless index = pcs.bsearch_index { |pc| pc >= low }

            name = nil
            while index < pcs.size && pcs[index] <= high
              unless functions[index]
                # the name is only materialized when a pc matched, and only
                # once for all the pcs it covers
                name ||= decode_dwarf_function_name(info, name_form, name_value, strings, line_strings)
                break unless name
                functions[index] = name
                remaining &-= 1
              end
              index += 1
            end
          end

          io.pos = Math.min(info.unit_end, bytes.size.to_i64)
        end
      end
    end
  end

  private def self.decode_dwarf_function_name(info, form : Crystal::DWARF::FORM, value : UInt64, strings, line_strings) : String?
    case form
    when .strp?
      strings.try(&.decode(value))
    when .line_strp?
      line_strings.try(&.decode(value))
    when .string?
      info.string_at(value)
    end
  end
end
