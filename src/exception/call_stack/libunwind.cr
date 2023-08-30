require "c/dlfcn"
require "c/stdio"
require "c/string"
require "../lib_unwind"

{% if flag?(:darwin) || flag?(:bsd) || flag?(:linux) %}
  require "./dwarf"
{% else %}
  require "./null"
{% end %}

struct Exception::CallStack
  skip(__FILE__)

  {% if flag?(:gnu) && flag?(:i386) %}
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

  def self.setup_crash_handler
    Crystal::System::Signal.setup_segfault_handler
  end

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_call_stack_unwind)] {% end %}
  protected def self.unwind : Array(Void*)
    callstack = Array(Void*).new(32)
    backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
      bt = data.as(typeof(callstack))

      ip = {% if flag?(:arm) %}
             Pointer(Void).new(__crystal_unwind_get_ip(context))
           {% else %}
             Pointer(Void).new(LibUnwind.get_ip(context))
           {% end %}
      bt << ip

      {% if flag?(:gnu) && flag?(:i386) %}
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

  def self.print_backtrace : Nil
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
    Crystal::System.print_error "[0x%llx] ", repeated_frame.ip.address.to_u64
    print_frame_location(repeated_frame)
    Crystal::System.print_error " (%d times)", repeated_frame.count + 1 unless repeated_frame.count == 0
    Crystal::System.print_error "\n"
  end

  private def self.print_frame_location(repeated_frame)
    {% if flag?(:debug) %}
      if @@dwarf_loaded &&
         (name = decode_function_name(repeated_frame.ip.address))
        file, line, column = Exception::CallStack.decode_line_number(repeated_frame.ip.address)
        if file && file != "??"
          Crystal::System.print_error "%s at %s:%d:%d", name, file, line, column
          return
        end
      end
    {% end %}

    if frame = decode_frame(repeated_frame.ip)
      offset, sname, fname = frame
      Crystal::System.print_error "%s +%lld in %s", sname, offset.to_i64, fname
    else
      Crystal::System.print_error "???"
    end
  end

  protected def self.decode_frame(ip, original_ip = ip)
    if LibC.dladdr(ip, out info) != 0
      offset = original_ip - info.dli_saddr

      if offset == 0
        return decode_frame(ip - 1, original_ip)
      end
      return if info.dli_sname.null? && info.dli_fname.null?
      if info.dli_sname.null?
        symbol = "??"
      else
        symbol = String.new(info.dli_sname)
      end
      if info.dli_fname.null?
        file = "??"
      else
        file = String.new(info.dli_fname)
      end
      {offset, symbol, file}
    end
  end
end
