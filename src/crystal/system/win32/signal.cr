require "c/signal"
require "c/malloc"

module Crystal::System::Signal
  def self.trap(signal, handler) : Nil
    raise NotImplementedError.new("Crystal::System::Signal.trap")
  end

  def self.trap_handler?(signal)
    raise NotImplementedError.new("Crystal::System::Signal.trap_handler?")
  end

  def self.reset(signal) : Nil
    raise NotImplementedError.new("Crystal::System::Signal.reset")
  end

  def self.ignore(signal) : Nil
    raise NotImplementedError.new("Crystal::System::Signal.ignore")
  end

  def self.setup_seh_handler
    LibC.AddVectoredExceptionHandler(1, ->(exception_info) do
      case exception_info.value.exceptionRecord.value.exceptionCode
      when LibC::EXCEPTION_ACCESS_VIOLATION
        addr = exception_info.value.exceptionRecord.value.exceptionInformation[1]
        Crystal::System.print_error "Invalid memory access (C0000005) at address %p\n", Pointer(Void).new(addr)
        {% if flag?(:gnu) %}
          Exception::CallStack.print_backtrace
        {% else %}
          Exception::CallStack.print_backtrace(exception_info)
        {% end %}
        LibC._exit(1)
      when LibC::EXCEPTION_STACK_OVERFLOW
        LibC._resetstkoflw
        Crystal::System.print_error "Stack overflow (e.g., infinite or very deep recursion)\n"
        {% if flag?(:gnu) %}
          Exception::CallStack.print_backtrace
        {% else %}
          Exception::CallStack.print_backtrace(exception_info)
        {% end %}
        LibC._exit(1)
      else
        LibC::EXCEPTION_CONTINUE_SEARCH
      end
    end)

    # ensure that even in the case of stack overflow there is enough reserved
    # stack space for recovery (for other threads this is done in
    # `Crystal::System::Thread.thread_proc`)
    stack_size = Crystal::System::Fiber::RESERVED_STACK_SIZE
    LibC.SetThreadStackGuarantee(pointerof(stack_size))

    # this catches invalid argument checks inside the C runtime library
    LibC._set_invalid_parameter_handler(->(expression, _function, _file, _line, _pReserved) do
      message = expression ? String.from_utf16(expression)[0] : "(no message)"
      Crystal::System.print_error "CRT invalid parameter handler invoked: %s\n", message
      caller.each do |frame|
        Crystal::System.print_error "  from %s\n", frame
      end
      LibC._exit(1)
    end)
  end
end
