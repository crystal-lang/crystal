require "callstack/lib_unwind"
require "callstack/addr2line"

{% if flag?(:linux) || flag?(:freebsd) %}
  require "callstack/elf"
  require "callstack/dwarf"
{% end %}

def caller
  CallStack.new.backtrace
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

  def backtrace
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
      ip = Pointer(Void).new(LibUnwind.get_ip(context))
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
      ip = Pointer(Void).new(LibUnwind.get_ip(context))
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
    ip16 = repeated_frame.ip.address.to_s(16)
    if frame
      offset, sname = frame
      if repeated_frame.count == 0
        LibC.printf "0x%s: %s +%ld\n", ip16, sname, offset
      else
        LibC.printf "0x%s: %s +%ld (%ld times)\n", ip16, sname, offset, repeated_frame.count + 1
      end
    else
      if repeated_frame.count == 0
        LibC.printf "0x%s: ???\n", ip16
      else
        LibC.printf "0x%s: ??? (%ld times)\n", ip16, repeated_frame.count + 1
      end
    end
  end

  private def decode_backtrace
    addr_size = {% if flag?(:i686) %}8{% else %}16{% end %}

    @callstack.map_with_index do |ip, index|
      path, line, column = decode_line_number(ip.address)
      next if @@skip.includes?(path)

      addr = ip.address.to_s(16).rjust(addr_size, '0')

      if frame = CallStack.decode_frame(ip)
        offset, sname = frame
        fname = String.new(sname)
      else
        fname = "???"
      end

      "0x#{addr}: #{fname} at #{path} #{line}:#{column}"
    end.compact
  end

  {% if flag?(:linux) || flag?(:freebsd)%}
    @dwarf_line_numbers : DWARF::LineNumbers?

    private def dwarf_line_numbers
      @dwarf_line_numbers ||= begin
        File.open(PROGRAM_NAME, "r") do |file|
          elf = ELF.new(file)
          elf.read_section?(".debug_line") do |sh, io|
            DWARF::LineNumbers.new(io, sh.size)
          end
        end
      end
    end

    private def decode_line_number(address)
      if ln = dwarf_line_numbers
        if row = ln.find(address)
          path = ln.files[row.file]? || "??"
          if dirname = ln.directories[row.directory]?
            path = "#{dirname}/#{path}"
          end
          return {path, row.line, row.column}
        end
      end
      {"??", 0, 0}
    end
  {% else %}
    private def decode_line_number(address)
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
