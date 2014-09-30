ifdef darwin
  lib Unwind
    CURSOR_SIZE = 140
    CONTEXT_SIZE = 128

    REG_IP = -1

    fun get_context = unw_getcontext(context : C::SizeT*) : Int32
    fun init_local = unw_init_local(cursor : C::SizeT*, context : C::SizeT*) : Int32
    fun step = unw_step(cursor : C::SizeT*) : Int32
    fun get_reg = unw_get_reg(cursor : C::SizeT*, regnum : Int32, reg : C::SizeT*) : Int32
    fun get_proc_name = unw_get_proc_name(cursor : C::SizeT*, name : UInt8*, size : Int32, offset : C::SizeT*) : Int32
  end
elsif linux
  ifdef x86_64
    @[Link("unwind")]
    lib Unwind
      CURSOR_SIZE = 140
      CONTEXT_SIZE = 128

      REG_IP = -1

      fun get_context = _Ux86_64_getcontext(context : C::SizeT*) : Int32
      fun init_local = _ULx86_64_init_local(cursor : C::SizeT*, context : C::SizeT*) : Int32
      fun step = _ULx86_64_step(cursor : C::SizeT*) : Int32
      fun get_reg = _ULx86_64_get_reg(cursor : C::SizeT*, regnum : Int32, reg : C::SizeT*) : Int32
      fun get_proc_name = _ULx86_64_get_proc_name(cursor : C::SizeT*, name : UInt8*, size : Int32, offset : C::SizeT*) : Int32
    end
  else
    @[Link("unwind")]
    lib Unwind
      CURSOR_SIZE = 127
      CONTEXT_SIZE = 87

      REG_IP = -1

      fun get_context = getcontext(context : C::SizeT*) : Int32
      fun init_local = _ULx86_init_local(cursor : C::SizeT*, context : C::SizeT*) : Int32
      fun step = _ULx86_step(cursor : C::SizeT*) : Int32
      fun get_reg = _ULx86_get_reg(cursor : C::SizeT*, regnum : Int32, reg : C::SizeT*) : Int32
      fun get_proc_name = _ULx86_get_proc_name(cursor : C::SizeT*, name : UInt8*, size : Int32, offset : C::SizeT*) : Int32
    end
  end
end

def caller
  cursor = Pointer(C::SizeT).malloc(Unwind::CURSOR_SIZE)
  context = Pointer(C::SizeT).malloc(Unwind::CONTEXT_SIZE)

  Unwind.get_context(context)
  Unwind.init_local(cursor, context)
  fname_size = 64
  fname_buffer = Pointer(UInt8).malloc(fname_size)

  backtrace = [] of String
  while Unwind.step(cursor) > 0
    Unwind.get_reg(cursor, Unwind::REG_IP, out pc)
    while true
      Unwind.get_proc_name(cursor, fname_buffer, fname_size, out offset)
      fname = String.new(fname_buffer)
      break if fname.length < fname_size - 1

      fname_size += 64
      fname_buffer = fname_buffer.realloc(fname_size)
    end
    backtrace << "#{fname} +#{offset} [#{pc}]"
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

class IndexOutOfBounds < Exception
  def initialize(message = "Index out of bounds")
    super(message)
  end
end

class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

class MissingKey < Exception
end

class DivisionByZero < Exception
  def initialize(message = "Division by zero")
    super(message)
  end
end
