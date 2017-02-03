require "c/dlfcn"
require "c/stdio"
require "c/string"
require "callstack/lib_unwind"

{% if flag?(:darwin) %}
  require "debug/mach_o"
  require "debug/dwarf"

  lib LibC
    fun _dyld_image_count : UInt32
    fun _dyld_get_image_name(image_index : UInt32) : Char*
    fun _dyld_get_image_vmaddr_slide(image_index : UInt32) : Long
  end
{% elsif flag?(:freebsd) || flag?(:linux) || flag?(:openbsd) %}
  require "debug/elf"
  require "debug/dwarf"
{% end %}

def caller
  CallStack.new.printable_backtrace
end

# :nodoc:
struct CallStack
  @@skip = [] of String

  def self.skip(filename)
    @@skip << filename
  end

  skip(__FILE__)

  @callstack : Array(Void*)
  @backtrace : Array(String)?

  def initialize
    @callstack = CallStack.unwind
  end

  def printable_backtrace
    @backtrace ||= decode_backtrace
  end

  {% if flag?(:gnu) && flag?(:i686) %}
    # This is only used for the workaround described in `Exception.unwind`
    @@makecontext_range : Range(Void*, Void*)?

    def self.makecontext_range
      @@makecontext_range ||= begin
        makecontext_start = makecontext_end = LibC.dlsym(LibC::RTLD_DEFAULT, "makecontext")

        while true
          ret = LibC.dladdr(makecontext_end, out info)
          break if ret == 0 || info.dli_sname.null?
          break unless LibC.strcmp(info.dli_sname, "makecontext") == 0
          makecontext_end += 1
        end

        (makecontext_start...makecontext_end)
      end
    end
  {% end %}

  protected def self.unwind
    callstack = [] of Void*
    backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
      bt = data.as(typeof(callstack))

      ip = {% if flag?(:arm) %}
             Pointer(Void).new(__crystal_unwind_get_ip(context))
           {% else %}
             Pointer(Void).new(LibUnwind.get_ip(context))
           {% end %}
      bt << ip

      {% if flag?(:gnu) && flag?(:i686) %}
        # This is a workaround for glibc bug: https://sourceware.org/bugzilla/show_bug.cgi?id=18635
        # The unwind info is corrupted when `makecontext` is used.
        # Stop the backtrace here. There is nothing interest beyond this point anyway.
        if CallStack.makecontext_range.includes?(ip)
          return LibUnwind::ReasonCode::END_OF_STACK
        end
      {% end %}

      LibUnwind::ReasonCode::NO_REASON
    end

    LibUnwind.backtrace(backtrace_fn, callstack.as(Void*))
    callstack
  end

  struct RepeatedFrame
    getter ip : Void*, count : Int32

    def initialize(@ip : Void*)
      @count = 0
    end

    def incr
      @count += 1
    end
  end

  def self.print_backtrace
    backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
      last_frame = data.as(RepeatedFrame*)

      ip = {% if flag?(:arm) %}
             Pointer(Void).new(__crystal_unwind_get_ip(context))
           {% else %}
             Pointer(Void).new(LibUnwind.get_ip(context))
           {% end %}

      if last_frame.value.ip == ip
        last_frame.value.incr
      else
        print_frame(last_frame.value) unless last_frame.value.ip.address == 0
        last_frame.value = RepeatedFrame.new ip
      end
      LibUnwind::ReasonCode::NO_REASON
    end

    rf = RepeatedFrame.new(Pointer(Void).null)
    LibUnwind.backtrace(backtrace_fn, pointerof(rf).as(Void*))
    print_frame(rf)
  end

  private def self.print_frame(repeated_frame)
    frame = decode_frame(repeated_frame.ip)
    if frame
      offset, sname = frame
      if repeated_frame.count == 0
        LibC.printf "[%ld] %s +%ld\n", repeated_frame.ip, sname, offset
      else
        LibC.printf "[%ld] %s +%ld (%ld times)\n", repeated_frame.ip, sname, offset, repeated_frame.count + 1
      end
    else
      if repeated_frame.count == 0
        LibC.printf "[%ld] ???\n", repeated_frame.ip
      else
        LibC.printf "[%ld] ??? (%ld times)\n", repeated_frame.ip, repeated_frame.count + 1
      end
    end
  end

  private def decode_backtrace
    @callstack.compact_map do |ip|
      file, line, column = CallStack.decode_line_number(ip)
      if file == "??"
        file_line_column = "??"
      else
        next if @@skip.includes?(file)
        file_line_column = "#{file} #{line}:#{column}"
      end

      if frame = CallStack.decode_frame(ip)
        _, sname = frame
        function = String.new(sname)
      else
        function = "???"
      end

      "0x#{ip.address.to_s(16)}: #{function} at #{file_line_column}"
    end
  end

  {% if flag?(:darwin) || flag?(:freebsd) || flag?(:linux) || flag?(:openbsd) %}
    @@dwarf_line_numbers : Debug::DWARF::LineNumbers?

    protected def self.decode_line_number(ip)
      if ln = dwarf_line_numbers
        if row = ln.find(decode_address(ip))
          path = ln.files[row.file]?
          if dirname = ln.directories[row.directory]?
            path = "#{dirname}/#{path}"
          end
          return {path, row.line, row.column}
        end
      end
      {"??", 0, 0}
    end

    {% if flag?(:darwin) %}
      @@image_slide : LibC::Long?

      protected def self.dwarf_line_numbers
        @@dwarf_line_numbers ||= locate_dsym_bundle do |mach_o|
          mach_o.read_section?("__debug_line") do |sh, io|
            Debug::DWARF::LineNumbers.new(io, sh.size)
          end
        end
      end

      # DWARF uses fixed addresses but Darwin loads exectutables at a random
      # address, so we must remove the load offset from the IP to match the
      # addresses in DWARF sections.
      #
      # See https://en.wikipedia.org/wiki/Address_space_layout_randomization
      protected def self.decode_address(ip)
        ip.address - image_slide
      end

      # Searches the companion dSYM bundle with the DWARF sections for the
      # current program as generated by `dsymutil`. It may be a `foo.dwarf` file
      # or within a `foo.dSYM` bundle for a program named `foo`.
      #
      # See <http://wiki.dwarfstd.org/index.php?title=Apple%27s_%22Lazy%22_DWARF_Scheme> for details.
      private def self.locate_dsym_bundle
        program = Process.executable_path
        return unless program

        files = {
          "#{program}.dSYM/Contents/Resources/DWARF/#{File.basename(program)}",
          "#{program}.dwarf"
        }

        files.each do |dwarf|
          next unless File.exists?(dwarf)

          Debug::MachO.open(program) do |mach_o|
            Debug::MachO.open(dwarf) do |dsym|
              if dsym.uuid == mach_o.uuid
                return yield dsym
              end
            end
          end
        end

        nil
      end

      # The address offset at which the program was loaded at.
      private def self.image_slide
        @@image_slide ||= search_image_slide
      end

      private def self.search_image_slide
        buffer = GC.malloc_atomic(LibC::PATH_MAX).as(UInt8*)
        size = LibC::PATH_MAX.to_u32

        if LibC._NSGetExecutablePath(buffer, pointerof(size)) == -1
          buffer = GC.malloc_atomic(size).as(UInt8*)
          if LibC._NSGetExecutablePath(buffer, pointerof(size)) == -1
            return LibC::Long.new(0)
          end
        end

        program = String.new(buffer)

        LibC._dyld_image_count.times do |i|
          if program == String.new(LibC._dyld_get_image_name(i))
            return LibC._dyld_get_image_vmaddr_slide(i)
          end
        end

        LibC::Long.new(0)
      end
    {% else %}
      @@base_address : UInt64|UInt32|Nil

      protected def self.dwarf_line_numbers
        @@dwarf_line_numbers ||= Debug::ELF.open(PROGRAM_NAME) do |elf|
          elf.read_section?(".text") do |sh, _|
            @@base_address = sh.addr - sh.offset
          end

          elf.read_section?(".debug_line") do |sh, io|
            Debug::DWARF::LineNumbers.new(io, sh.size)
          end
        end
      end

      # DWARF uses fixed addresses but some platforms (e.g., OpenBSD or Linux
      # with the [PaX patch](https://en.wikipedia.org/wiki/PaX)) load
      # executables at a random address, so we must remove the load offset from
      # the IP to match the addresses in DWARF sections.
      #
      # See https://en.wikipedia.org/wiki/Address_space_layout_randomization
      protected def self.decode_address(ip)
        if LibC.dladdr(ip, out info) != 0
          unless info.dli_fbase.address == @@base_address
            return ip.address - info.dli_fbase.address
          end
        end
        ip.address
      end
    {% end %}
  {% else %}
    def self.decode_line_number(ip)
      {"??", 0, 0}
    end
  {% end %}

  protected def self.decode_frame(ip, original_ip = ip)
    if LibC.dladdr(ip, out info) != 0
      offset = original_ip - info.dli_saddr

      if offset == 0
        return decode_frame(ip - 1, original_ip)
      end

      unless info.dli_sname.null?
        {offset, info.dli_sname}
      end
    end
  end
end
