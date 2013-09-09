lib Unwind
  CURSOR_SIZE = 140
  CONTEXT_SIZE = 128

  REG_IP = -1

  fun get_context = unw_getcontext(context : Int64*) : Int32
  fun init_local = unw_init_local(cursor : Int64*, context : Int64*) : Int32
  fun step = unw_step(cursor : Int64*) : Int32
  fun get_reg = unw_get_reg(cursor : Int64*, regnum : Int32, reg : UInt64*) : Int32
  fun get_proc_name = unw_get_proc_name(cursor : Int64*, name : Char*, size : Int32, offset : UInt64*) : Int32
end

class Exception
  getter :message
  getter :inner_exception
  getter :backtrace

  def initialize(message = nil : String?, inner_exception = nil : Exception?)
    @message = message
    @inner_exception = inner_exception

    cursor = Pointer(Int64).malloc(Unwind::CURSOR_SIZE)
    context = Pointer(Int64).malloc(Unwind::CONTEXT_SIZE)

    Unwind.get_context(context)
    Unwind.init_local(cursor, context)
    fname = Pointer(Char).malloc(64)

    @backtrace = [] of String
    while Unwind.step(cursor) > 0
      Unwind.get_reg(cursor, Unwind::REG_IP, out pc)
      Unwind.get_proc_name(cursor, fname, 64, out offset)
      @backtrace << "#{String.from_cstr(fname)}+#{offset} [#{pc}]"
    end
  end

  def to_s
    bt = @backtrace.join("\n")
    if @message
      "#{@message}:\n#{bt}"
    else
      bt
    end
  end
end
