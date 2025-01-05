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
      ret = LibC.SleepConditionVariableCS(self, mutex, LibC::INFINITE)
      raise RuntimeError.from_winerror("SleepConditionVariableCS") if ret == 0
    end

    def wait(mutex : Thread::Mutex, time : Time::Span, & : ->)
      ret = LibC.SleepConditionVariableCS(self, mutex, time.total_milliseconds)
      return if ret != 0

      error = WinError.value
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
