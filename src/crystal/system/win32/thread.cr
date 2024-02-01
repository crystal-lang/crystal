require "c/processthreadsapi"
require "c/synchapi"

module Crystal::System::Thread
  alias Handle = LibC::HANDLE

  def to_unsafe
    @system_handle
  end

  private def init_handle
    @system_handle = GC.beginthreadex(
      security: Pointer(Void).null,
      stack_size: LibC::UInt.zero,
      start_address: ->Thread.thread_proc(Void*),
      arglist: self.as(Void*),
      initflag: LibC::UInt.zero,
      thrdaddr: Pointer(LibC::UInt).null,
    )
  end

  def self.thread_proc(data : Void*) : LibC::UInt
    # ensure that even in the case of stack overflow there is enough reserved
    # stack space for recovery (for the main thread this is done in
    # `Exception::CallStack.setup_crash_handler`)
    stack_size = Crystal::System::Fiber::RESERVED_STACK_SIZE
    LibC.SetThreadStackGuarantee(pointerof(stack_size))

    data.as(::Thread).start
    LibC::UInt.zero
  end

  def self.current_handle : Handle
    # `GetCurrentThread` returns a _constant_ and is only meaningful as an
    # argument to Win32 APIs; to uniquely identify it we must duplicate the handle
    cur_proc = LibC.GetCurrentProcess
    if LibC.DuplicateHandle(cur_proc, LibC.GetCurrentThread, cur_proc, out handle, 0, true, LibC::DUPLICATE_SAME_ACCESS) == 0
      raise RuntimeError.from_winerror("DuplicateHandle")
    end
    handle
  end

  def self.yield_current : Nil
    LibC.SwitchToThread
  end

  @[ThreadLocal]
  class_property current_thread : ::Thread { ::Thread.new }

  private def system_join : Exception?
    if LibC.WaitForSingleObject(@system_handle, LibC::INFINITE) != LibC::WAIT_OBJECT_0
      return RuntimeError.from_winerror("WaitForSingleObject")
    end
    if LibC.CloseHandle(@system_handle) == 0
      return RuntimeError.from_winerror("CloseHandle")
    end
  end

  private def system_close
    LibC.CloseHandle(@system_handle)
  end

  private def stack_address : Void*
    {% if LibC.has_method?("GetCurrentThreadStackLimits") %}
      LibC.GetCurrentThreadStackLimits(out low_limit, out high_limit)
      Pointer(Void).new(low_limit)
    {% else %}
      tib = LibC.NtCurrentTeb
      high_limit = tib.value.stackBase
      LibC.VirtualQuery(tib.value.stackLimit, out mbi, sizeof(LibC::MEMORY_BASIC_INFORMATION))
      low_limit = mbi.allocationBase
      low_limit
    {% end %}
  end

  private def system_name=(name : String) : String
    {% if LibC.has_method?(:SetThreadDescription) %}
      LibC.SetThreadDescription(@system_handle, System.to_wstr(name))
    {% end %}
    name
  end
end
