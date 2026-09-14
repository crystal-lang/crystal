module Crystal
  module DWARF
    class Backtraces
      property debug_abbrev : Bytes?
      property debug_info : Bytes?
      property debug_line : Bytes?
      property debug_line_str : Bytes?
      property debug_str : Bytes?

      # The decoded table for resolving function names; parsed once from the
      # debug info and debug abbrev sections; the table is much smaller than the
      # sections (that has lots of debug into we don't need), and much faster to
      # search through.
      #
      # OPTIMIZE: reduce the table row size, for example using offsets (u32)
      # instead of absolute PCs (u64) to save 8 bytes out of every entry.
      @function_names = Slice({UInt64, UInt64, UInt8*}).empty

      @initialized = false

      def build_caches : Nil
        preload_function_names
        @initialized = true
      end

      def lookup_function_name(pc : Int) : Bytes?
        return unless @initialized

        a = @function_names
        l, r = 0, a.size

        while l < r
          m = l &+ (r &- l) // 2
          low_pc, high_pc, cstring = a.to_unsafe[m]

          if low_pc <= pc <= high_pc
            return Bytes.new(cstring, LibC.strlen(cstring))
          end

          if low_pc < pc
            l = m &+ 1
          else
            r = m
          end
        end

        nil
      end

      private def preload_function_names : Nil
        return unless debug_info = @debug_info

        # index to each individual abbreviation at an abbrev offset, so we don't
        # have to scan DEBUG_ABBREV over and over again to find the abbrevs
        # we're looking for, we can directly pinpoint the abbrev we need; this
        # dramatically improves the performance of parsing the DEBUG_INFO section
        abbrev_indexes = Hash(UInt64, Array(Int32)).new

        # use the length of the DEBUG_INFO as the oversized mmap size; the final
        # table is always only a fraction of the section's size
        table = memory_map(debug_info.bytesize, Tuple(UInt64, UInt64, UInt8*)) do |slice|
          size = 0

          each_function_name(abbrev_indexes) do |low_pc, high_pc, name_form, name_value|
            # we take advantage that DWARF strings are always NULL terminated to
            # only save the pointer and reduce the table's size by 25%
            name_ptr = decode_str_pointer(name_form, name_value)

            unless name_ptr.null?
              slice[size] = {low_pc, high_pc, name_ptr}
              size += 1
            end
          end

          size
        end

        return unless table

        # while the low/high PC are mostly growing while following the debug
        # info, they actually aren't perfectly sorted in ascending order, and
        # must sort the table for binary searches
        @function_names = table.sort! do |a, b|
          cmp = a[0] <=> b[0]
          cmp == 0 ? a[1] <=> b[1] : cmp
        end
      end

      private def each_function_name(abbrev_indexes, &)
        return unless debug_abbrev = @debug_abbrev
        return unless debug_info = @debug_info

        DWARF.each_info(debug_info) do |info|
          abbrev_table = debug_abbrev + info.debug_abbrev_offset
          abbrev_index = abbrev_indexes[info.debug_abbrev_offset] ||= parse_abbrev_indexes(abbrev_table)

          info.each do |abbrev_code|
            offset = abbrev_index[abbrev_code &- 1]

            DWARF.abbrev_at(abbrev_table + offset) do |abbrev|
              if abbrev.tag == DW_TAG_subprogram
                low_pc = nil
                high_pc = nil
                name_form = nil
                name_value = nil

                abbrev.each_attribute do |attr|
                  value = info.read_attribute_value(attr.form, attr.const_value)

                  case attr.at
                  when DW_AT_low_pc
                    low_pc = value.as(LibC::SizeT)
                  when DW_AT_high_pc
                    if attr.form == DW_FORM_addr
                      high_pc = value.as(LibC::SizeT)
                    elsif value.responds_to?(:to_u64)
                      high_pc = low_pc.as(LibC::SizeT) + value.to_u64
                    end
                  when DW_AT_name
                    name_form = attr.form
                    name_value = value
                  end
                end

                if low_pc && high_pc && name_form && name_value
                  yield low_pc, high_pc, name_form, name_value
                end
              else
                abbrev.each_attribute do |attr|
                  info.skip_attribute_value(attr.form)
                end
              end
            end
          end
        end
      end

      private def parse_abbrev_indexes(abbrev_table)
        Array(Int32).new.tap do |index|
          Crystal::DWARF.each_abbrev(abbrev_table) do |abbrev, offset|
            index << offset
            abbrev.each_attribute { }
          end
        end
      end

      def lookup_line_number(pc : Int) : {Bytes, Bytes, UInt32, UInt32} | Nil
        each_line_number do |sequence, low_pc, limit_pc, file_index, line, column|
          if low_pc <= pc < limit_pc
            directory, file = file_and_directory_at(sequence, file_index)
            return directory, file, line, column
          end
        end
      end

      def each_line_number(&) : Nil
        return unless @initialized
        return unless debug_line = @debug_line

        DWARF.each_line_sequence(debug_line) do |sequence|
          # state of the previous entry in the matrix
          address = 0_u64
          file_index = 0_u32
          line = 0_u32
          column = 0_u32

          registers = Line::Registers.new(sequence.default_is_stmt?)

          sequence.read_statement_program(pointerof(registers)) do
            unless address.zero? || line.zero?
              yield pointerof(sequence), address, registers.address, file_index, line, column
            end

            # save state
            if registers.end_sequence?
              address = 0_u64
            else
              address = registers.address
            end
            file_index = registers.file
            line = registers.line
            column = registers.column
          end
        end
      end

      private def file_and_directory_at(sequence, file_index)
        file = Bytes.empty
        directory = Bytes.empty
        directory_index = 0

        # must parse directories before we can parse files (skip)
        sequence.value.each_directory { }

        # files are 1-indexed
        i = 1
        sequence.value.each_file do |(form, value), dir_index, _, _, _|
          if i == file_index
            file = decode_str(form, value)
            directory_index = dir_index
            break
          end
          i += 1
        end

        unless file.empty?
          case directory_index
          when 0
            # special case
            directory = ".".to_slice
          else
            # re-parse the directories to get the file's directory
            sequence.value.rewind_headers

            # directories are 1-indexed
            i = 1
            sequence.value.each_directory do |(form, value)|
              if i == directory_index
                directory = decode_str(form, value)
                break
              end
              i += 1
            end
          end
        end

        {directory, file}
      end

      private def decode_str(form, value)
        case form
        when DW_FORM_string
          value.as(Bytes)
        when DW_FORM_strp
          decode_strp(@debug_str, value.as(UInt8 | UInt16 | UInt32 | UInt64))
        when DW_FORM_line_strp
          decode_strp(@debug_line_str, value.as(UInt8 | UInt16 | UInt32 | UInt64))
        else
          Bytes.empty
        end
      end

      private def decode_str_pointer(form, value)
        case form
        when DW_FORM_string
          value.as(Bytes).to_unsafe
        when DW_FORM_strp
          decode_strp_pointer(@debug_str, value.as(UInt8 | UInt16 | UInt32 | UInt64))
        when DW_FORM_line_strp
          decode_strp_pointer(@debug_line_str, value.as(UInt8 | UInt16 | UInt32 | UInt64))
        else
          Pointer(UInt8).null
        end
      end

      private def decode_strp(bytes, offset)
        if pointer = decode_strp_pointer(bytes, offset)
          bytesize = LibC.strlen(pointer).to_i32
          Bytes.new(pointer, bytesize, read_only: true)
        else
          Bytes.empty
        end
      end

      private def decode_strp_pointer(bytes, offset)
        if bytes && (0 <= offset < bytes.size)
          bytes.to_unsafe + offset
        else
          Pointer(UInt8).null
        end
      end

      # The DWARF format doesn't give us any indication of how many entries
      # we're expecting and thus can't pre-allocate to the final size.
      #
      # We don't need to allocate in GC HEAP, the tables live until the program
      # terminates and don't contain pointers to GC HEAP memory to retain, they
      # only point to map memory.
      #
      # Using an Array would lead to reallocate its internal buffer many times,
      # requiring much more memory than necessary (several MB vs a few hundred
      # KB) and lots of memory copy.
      #
      # Instead, we overallocate an anonymous memory map, let the caller fill
      # some of it, then truncate the overallocated pages.
      private def memory_map(bytesize, type : F.class, &) forall F
        # align to page size
        page_size =
          {% if flag?(:win32) %}
            LibC.GetNativeSystemInfo(out system_info)
            system_info.dwPageSize.to_u64
          {% else %}
            LibC.sysconf(LibC::SC_PAGESIZE).to_u64
          {% end %}
        aligned_bytesize = (bytesize.to_u64 &+ (page_size &- 1)) & (&-page_size)

        # allocate
        #
        # OPTIMIZE: hint the OS that we need the pages to reduce page faults (?)
        pointer = Pointer(Void).null
        {% if flag?(:win32) %}
          pointer = LibC.VirtualAlloc(nil, aligned_bytesize, LibC::MEM_RESERVE | LibC::MEM_COMMIT, LibC::PAGE_READWRITE)
          return if pointer.null?
        {% else %}
          pointer = LibC.mmap(nil, aligned_bytesize, LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_PRIVATE | LibC::MAP_ANON, -1, 0)
          return if pointer == LibC::MAP_FAILED
        {% end %}

        # let caller fill what's needed
        slice = Slice(F).new(pointer.as(F*), aligned_bytesize // sizeof(F))
        actual_size = yield slice

        # determine overallocation
        aligned_boundary = (pointer + actual_size * sizeof(F)).align_up(page_size)
        limit = pointer + aligned_bytesize
        oversize = limit - aligned_boundary

        # truncate the overallocation, if any
        unless oversize == 0
          {% if flag?(:win32) %}
            LibC.VirtualFree(aligned_boundary, oversize, LibC::MEM_DECOMMIT)
          {% else %}
            LibC.munmap(aligned_boundary, oversize)
          {% end %}
        end

        slice[0, actual_size]
      end
    end
  end
end
