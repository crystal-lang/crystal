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
    lib Unwind("unwind")
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
    lib Unwind("unwind")
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
  def initialize(message = nil : String?, inner_exception = nil : Exception?)
    @message = message
    @inner_exception = inner_exception
    @backtrace = caller
  end

  def message
    @message
  end

  def inner_exception
    @inner_exception
  end

  def backtrace
    @backtrace
  end

  def to_s
    bt = @backtrace
    ifdef linux
      bt = bt.map! { |frame| Exception.unescape_linux_backtrace_frame(frame) }
    end
    bt = bt.join("\n")
    if @message
      "#{@message}\n#{bt}"
    else
      bt
    end
  end

  def self.unescape_linux_backtrace_frame(frame)
    frame.replace(/_(\d|A|B|C|D|E|F)(\d|A|B|C|D|E|F)_/) do |match|
      first = match[1].chr.to_i(16) * 16
      second = match[2].chr.to_i(16)
      value = first + second
      value.chr
    end
  end
end

class EmptyEnumerable < Exception
end

class IndexOutOfBounds < Exception
end

class ArgumentError < Exception
end
