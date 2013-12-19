lib Unwind("unwind")
  CURSOR_SIZE = 127
  CONTEXT_SIZE = 87

  REG_IP = -1

  fun get_context = getcontext(context : C::SizeT*) : Int32
  fun init_local = _ULx86_init_local(cursor : C::SizeT*, context : C::SizeT*) : Int32
  fun step = _ULx86_step(cursor : C::SizeT*) : Int32
  fun get_reg = _ULx86_get_reg(cursor : C::SizeT*, regnum : Int32, reg : C::SizeT*) : Int32
  fun get_proc_name = _ULx86_get_proc_name(cursor : C::SizeT*, name : Char*, size : Int32, offset : C::SizeT*) : Int32
end

class Exception
  def self.needs_to_unescape_backtraces?
    true
  end

  def self.unescape_backtrace(frame)
    unescape_linux_backtrace_frame(frame)
  end
end
