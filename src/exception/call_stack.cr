{% skip_file if flag?(:win32) %}

require "c/dlfcn"
require "c/stdio"
require "c/string"
require "./lib_unwind"

{% if flag?(:darwin) || flag?(:bsd) || flag?(:linux) %}
  require "./call_stack/dwarf"
{% else %}
  require "./call_stack/null"
{% end %}

# Returns the current execution stack as an array containing strings
# usually in the form file:line:column or file:line:column in 'method'.
def caller : Array(String)
  Exception::CallStack.new.printable_backtrace
end

# Returns the current execution stack as an array of `Exception::CallStack::Frame`.
def caller_frames : Array(Exception::CallStack::Frame)
  Exception::CallStack.new.frames
end

struct Exception::CallStack
  # Represents a specific frame within an `Exception#backtrace`;
  # exposing the location, function name, and memory address (if available).
  struct Frame
    # Returns the file that at which the exception occurred.
    #
    # Assuming a frame like `/home/crystal/test.cr:24:5 in 'test_method' at 0x55df02499e76`,
    # the file would be `/home/crystal/test.cr`.
    getter file : String

    # Returns the function name in which the exception occurred.
    #
    # Assuming a frame like `/home/crystal/test.cr:24:5 in 'test_method' at 0x55df02499e76`,
    # the function would be `test_method`.
    getter function : String

    # Returns the line number in which the exception occurred.
    #
    # Assuming a frame like `/home/crystal/test.cr:24:5 in 'test_method' at 0x55df02499e76`,
    # the line number would be `24`.
    getter line_number : Int32

    # Returns the column number in which the exception occurred.
    #
    # Assuming a frame like `/home/crystal/test.cr:24:5 in 'test_method' at 0x55df02499e76`,
    # the column number would be `5`.
    getter column_number : Int32

    protected def initialize(
      @file : String,
      @function : String,
      @line_number : Int32,
      @column_number : Int32,
      @address : String? = nil
    )
    end

    def_equals_and_hash @function, @file, @line_number, @column_number, @address

    # Returns the filename of `#file`.
    #
    # ```
    # frame.file     # => /home/crystal/test.cr
    # frame.filename # => test.cr
    # ```
    def filename : String
      File.basename @file
    end

    # Returns a `Path` instance of `#file`.
    def file_path : Path
      Path.new @file
    end

    # Returns a `String` representation of `self` as you would see it in `Exception#backtrace`.
    def to_s(io : IO) : Nil
      io << @file << ':' << @line_number << ':' << @column_number
      io << " in " << '\'' << @function << '\''
      io << " at " << "0x#{@address}" if @address
    end
  end

  # Compute current directory at the beginning so filenames
  # are always shown relative to the *starting* working directory.
  private CURRENT_DIR = begin
    dir = Process::INITIAL_PWD
    dir += File::SEPARATOR unless dir.ends_with?(File::SEPARATOR)
    dir
  end

  @@skip = [] of String

  # :nodoc:
  def self.skip(filename)
    @@skip << filename
  end

  skip(__FILE__)

  @callstack : Array(Void*)
  @backtrace : Array(String)?

  # :nodoc:
  getter frames : Array(Frame) { decode_backtrace }

  # :nodoc:
  def initialize
    @callstack = CallStack.unwind
  end

  # :nodoc:
  def printable_backtrace
    self.frames.map &.to_s
  end

  {% if flag?(:gnu) && flag?(:i386) %}
    # This is only used for the workaround described in `Exception.unwind`
    @@makecontext_range : Range(Void*, Void*)?

    # :nodoc:
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

  # :nodoc:
  struct RepeatedFrame
    getter ip : Void*, count : Int32

    def initialize(@ip : Void*)
      @count = 0
    end

    def incr
      @count += 1
    end
  end

  # :nodoc:
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
    {% if flag?(:debug) %}
      if @@dwarf_loaded &&
         (name = decode_function_name(repeated_frame.ip.address))
        file, line, column = Exception::CallStack.decode_line_number(repeated_frame.ip.address)
        if file && file != "??"
          if repeated_frame.count == 0
            Crystal::System.print_error "[0x%lx] %s at %s:%ld:%i\n", repeated_frame.ip, name, file, line, column
          else
            Crystal::System.print_error "[0x%lx] %s at %s:%ld:%i (%ld times)\n", repeated_frame.ip, name, file, line, column, repeated_frame.count + 1
          end
          return
        end
      end
    {% end %}

    frame = decode_frame(repeated_frame.ip)
    if frame
      offset, sname = frame
      if repeated_frame.count == 0
        Crystal::System.print_error "[0x%lx] %s +%ld\n", repeated_frame.ip, sname, offset
      else
        Crystal::System.print_error "[0x%lx] %s +%ld (%ld times)\n", repeated_frame.ip, sname, offset, repeated_frame.count + 1
      end
    else
      if repeated_frame.count == 0
        Crystal::System.print_error "[0x%lx] ???\n", repeated_frame.ip
      else
        Crystal::System.print_error "[0x%lx] ??? (%ld times)\n", repeated_frame.ip, repeated_frame.count + 1
      end
    end
  end

  private def decode_backtrace : Array(Frame)
    show_full_info = ENV["CRYSTAL_CALLSTACK_FULL_INFO"]? == "1"

    @callstack.compact_map do |ip|
      pc = CallStack.decode_address(ip)

      has_file_reference = false

      file, line_number, column_number = CallStack.decode_line_number(pc)

      if file && file != "??"
        next if @@skip.includes?(file)

        # Turn to relative to the current dir, if possible
        filename = file.lchop(CURRENT_DIR)

        has_file_reference = true
      elsif file
        filename = file
      else
        filename = "???"
      end

      if name = CallStack.decode_function_name(pc)
        function = name
      elsif frame = CallStack.decode_frame(ip)
        _, sname = frame
        function = String.new(sname)

        # Crystal methods (their mangled name) start with `*`, so
        # we remove that to have less clutter in the output.
        function = function.lchop('*')
      else
        function = "???"
      end

      if has_file_reference && show_full_info && (frame = CallStack.decode_frame(ip))
        _, sname = frame
        function = "#{String.new(sname)}"
      end

      if show_full_info
        address = ip.address.to_s(16)
      end

      Frame.new filename, function, line_number, column_number, address
    end
  end

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
