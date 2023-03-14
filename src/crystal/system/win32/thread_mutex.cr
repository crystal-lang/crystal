require "c/synchapi"

# :nodoc:
class Thread
  # :nodoc:
  # for Win32 condition variable interop we must use either a critical section
  # or a slim reader/writer lock, not a Win32 mutex
  # also note critical sections are reentrant; to match the behaviour in
  # `../unix/pthread_mutex.cr` we must do extra housekeeping ourselves
  class Mutex
    def initialize
      @cs = uninitialized LibC::CRITICAL_SECTION
      LibC.InitializeCriticalSectionAndSpinCount(self, 1000)
    end

    def lock : Nil
      LibC.EnterCriticalSection(self)
      if @cs.recursionCount > 1
        LibC.LeaveCriticalSection(self)
        raise RuntimeError.new "Attempt to lock a mutex recursively (deadlock)"
      end
    end

    def try_lock : Bool
      if LibC.TryEnterCriticalSection(self) != 0
        if @cs.recursionCount > 1
          LibC.LeaveCriticalSection(self)
          false
        else
          true
        end
      else
        false
      end
    end

    def unlock : Nil
      # `owningThread` is declared as `LibC::HANDLE` for historical reasons, so
      # the following comparison is correct
      unless @cs.owningThread == LibC::HANDLE.new(LibC.GetCurrentThreadId)
        raise RuntimeError.new "Attempt to unlock a mutex locked by another thread"
      end
      LibC.LeaveCriticalSection(self)
    end

    def synchronize(&)
      lock
      yield self
    ensure
      unlock
    end

    def finalize
      LibC.DeleteCriticalSection(self)
    end

    def to_unsafe
      pointerof(@cs)
    end
  end
end
