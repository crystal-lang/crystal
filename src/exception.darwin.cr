lib Unwind
  CURSOR_SIZE = 140
  CONTEXT_SIZE = 128

  REG_IP = -1

  fun get_context = unw_getcontext(context : C::SizeT*) : Int32
  fun init_local = unw_init_local(cursor : C::SizeT*, context : C::SizeT*) : Int32
  fun step = unw_step(cursor : C::SizeT*) : Int32
  fun get_reg = unw_get_reg(cursor : C::SizeT*, regnum : Int32, reg : C::SizeT*) : Int32
  fun get_proc_name = unw_get_proc_name(cursor : C::SizeT*, name : Char*, size : Int32, offset : C::SizeT*) : Int32
end

class Exception
  def self.needs_to_unescape_backtraces?
    false
  end

  def self.unescape_backtrace(frame)
    frame
  end
end

