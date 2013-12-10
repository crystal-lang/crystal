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
  def self.needs_to_unescape_backtraces?
    false
  end

  def self.unescape_backtrace(frame)
    frame
  end
end

