lib Unwind("unwind")
  CURSOR_SIZE = 140
  CONTEXT_SIZE = 128

  REG_IP = -1

  fun get_context = _Ux86_64_getcontext(context : C::SizeT*) : Int32
  fun init_local = _ULx86_64_init_local(cursor : C::SizeT*, context : C::SizeT*) : Int32
  fun step = _ULx86_64_step(cursor : C::SizeT*) : Int32
  fun get_reg = _ULx86_64_get_reg(cursor : C::SizeT*, regnum : Int32, reg : C::SizeT*) : Int32
  fun get_proc_name = _ULx86_64_get_proc_name(cursor : C::SizeT*, name : Char*, size : Int32, offset : C::SizeT*) : Int32
end

class Exception
  def self.needs_to_unescape_backtraces?
    true
  end

  def self.unescape_backtrace(frame)
    unescape_linux_backtrace_frame(frame)
  end
end
