ifdef darwin
  lib Unwind
    type Cursor = LibC::SizeT[140]
    type Context = LibC::SizeT[128]

    REG_IP = -1

    fun get_context = unw_getcontext(context : Context*) : Int32
    fun init_local = unw_init_local(cursor : Cursor*, context : Context*) : Int32
    fun step = unw_step(cursor : Cursor*) : Int32
    fun get_reg = unw_get_reg(cursor : Cursor*, regnum : Int32, reg : LibC::SizeT*) : Int32
    fun get_proc_name = unw_get_proc_name(cursor : Cursor*, name : UInt8*, size : Int32, offset : LibC::SizeT*) : Int32
  end
elsif linux
  ifdef x86_64
    @[Link("unwind")]
    lib Unwind
      type Cursor = LibC::SizeT[140]
      type Context = LibC::SizeT[128]

      REG_IP = -1

      fun get_context = _Ux86_64_getcontext(context : Context*) : Int32
      fun init_local = _ULx86_64_init_local(cursor : Cursor*, context : Context*) : Int32
      fun step = _ULx86_64_step(cursor : Cursor*) : Int32
      fun get_reg = _ULx86_64_get_reg(cursor : Cursor*, regnum : Int32, reg : LibC::SizeT*) : Int32
      fun get_proc_name = _ULx86_64_get_proc_name(cursor : Cursor*, name : UInt8*, size : Int32, offset : LibC::SizeT*) : Int32
    end
  else
    @[Link("unwind")]
    lib Unwind
      type Cursor = LibC::SizeT[127]
      type Context = LibC::SizeT[87]

      REG_IP = -1

      fun get_context = getcontext(context : Context*) : Int32
      fun init_local = _ULx86_init_local(cursor : Cursor*, context : Context*) : Int32
      fun step = _ULx86_step(cursor : Cursor*) : Int32
      fun get_reg = _ULx86_get_reg(cursor : Cursor*, regnum : Int32, reg : LibC::SizeT*) : Int32
      fun get_proc_name = _ULx86_get_proc_name(cursor : Cursor*, name : UInt8*, size : Int32, offset : LibC::SizeT*) : Int32
    end
  end
end

def caller
  cursor :: Unwind::Cursor
  context :: Unwind::Context

  cursor_ptr = pointerof(cursor)
  context_ptr = pointerof(context)

  Unwind.get_context(context_ptr)
  Unwind.init_local(cursor_ptr, context_ptr)
  fname_size = 64
  fname_buffer = Pointer(UInt8).malloc(fname_size)

  backtrace = [] of String
  while Unwind.step(cursor_ptr) > 0
    Unwind.get_reg(cursor_ptr, Unwind::REG_IP, out pc)
    while true
      Unwind.get_proc_name(cursor_ptr, fname_buffer, fname_size, out offset)
      fname = String.new(fname_buffer)
      break if fname.length < fname_size - 1

      fname_size += 64
      fname_buffer = fname_buffer.realloc(fname_size)
    end
    backtrace << "#{fname} +#{offset} [#{pc}]"
    ifdef i686
      # This is a workaround for glibc bug: https://sourceware.org/bugzilla/show_bug.cgi?id=18635
      # The unwind info is corrupted when `makecontext` is used.
      # Stop the backtrace here. There is nothing interest beyond this point anyway.
      break if fname == "makecontext"
    end
  end
  backtrace
end

class Exception
  getter message
  getter cause
  getter backtrace

  def initialize(message = nil : String?, cause = nil : Exception?)
    @message = message
    @cause = cause
    @backtrace = caller
  end

  def backtrace
    backtrace = @backtrace
    ifdef linux
      backtrace = backtrace.map do |frame|
        Exception.unescape_linux_backtrace_frame(frame)
      end
    end
    backtrace
  end

  def to_s(io : IO)
    if @message
      io << @message
    end
  end

  def inspect_with_backtrace
    String.build do |io|
      inspect_with_backtrace io
    end
  end

  def inspect_with_backtrace(io : IO)
    io << self << " (" << self.class << ")\n"
    backtrace.each do |frame|
      io.puts frame
    end
    io.flush
  end

  def self.unescape_linux_backtrace_frame(frame)
    frame.gsub(/_(\d|A|B|C|D|E|F)(\d|A|B|C|D|E|F)_/) do |match|
      first = match[1].to_i(16) * 16
      second = match[2].to_i(16)
      value = first + second
      value.chr
    end
  end
end

class EmptyEnumerable < Exception
  def initialize(message = "Empty enumerable")
    super(message)
  end
end

# Raised when the given index is invalid.
#
# ```
# a = [:foo, :bar]
# a[2] #=> IndexError: index out of bounds
# ```
class IndexError < Exception
  def initialize(message = "Index out of bounds")
    super(message)
  end
end

# Raised when the arguments are wrong and there isn't a more specific `Exception` class.
#
# ```
# [1, 2, 3].take(-4) #=> ArgumentError: attempt to take negative size
# ```
class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

class DomainError < Exception
  def initialize(message = "Argument out of domain")
    super(message)
  end
end

class InvalidByteSequenceError < Exception
  def initialize(message = "Invalid byte sequence in UTF-8 string")
    super(message)
  end
end

# Raised when the specified key is not found.
#
# ```
# h = {"foo" => "bar"}
# h["baz"] #=> KeyError: Missing hash key: "baz"
# ```
class KeyError < Exception
end

class DivisionByZero < Exception
  def initialize(message = "Division by zero")
    super(message)
  end
end
