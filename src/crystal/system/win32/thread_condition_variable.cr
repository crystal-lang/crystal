require "c/synchapi"

# :nodoc:
class Thread
  # :nodoc:
  class ConditionVariable
    def initialize
      @cond = uninitialized LibC::CONDITION_VARIABLE
      LibC.InitializeConditionVariable(self)
    end

    def signal : Nil
      LibC.WakeConditionVariable(self)
    end

    def broadcast : Nil
      LibC.WakeAllConditionVariable(self)
    end

    def wait(mutex : Thread::Mutex) : Nil
      ret = 0
      GC.syscall(pointerof(ret), self, mutex) do |ret_ptr, self_, mutex_|
        ret_ptr.value = LibC.SleepConditionVariableCS(self_, mutex_, LibC::INFINITE)
      end
      raise RuntimeError.from_winerror("SleepConditionVariableCS") if ret == 0
    end

    def wait(mutex : Thread::Mutex, time : Time::Span, & : ->)
      ret, error = 0, WinError::ERROR_SUCCESS
      timeout = time.to_milliseconds

      GC.syscall(pointerof(ret), pointerof(errno), self, mutex, timeout) do |ret_ptr, error_ptr, self_, mutex_, timeout_|
        ret_ptr.value = LibC.SleepConditionVariableCS(self_, mutex_, timeout_)
        error_ptr.value = WinError.value
      end
      return if ret != 0

      if error == WinError::ERROR_TIMEOUT
        yield
      else
        raise RuntimeError.from_os_error("SleepConditionVariableCS", error)
      end
    end

    def to_unsafe
      pointerof(@cond)
    end
  end
end
