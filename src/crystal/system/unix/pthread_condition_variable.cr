require "c/pthread"

# :nodoc:
class Thread
  # :nodoc:
  class ConditionVariable
    def initialize
      attributes = uninitialized LibC::PthreadCondattrT
      LibC.pthread_condattr_init(pointerof(attributes))

      {% unless flag?(:darwin) %}
        LibC.pthread_condattr_setclock(pointerof(attributes), LibC::CLOCK_MONOTONIC)
      {% end %}

      ret = LibC.pthread_cond_init(out @cond, pointerof(attributes))
      raise RuntimeError.from_os_error("pthread_cond_init", Errno.new(ret)) unless ret == 0

      LibC.pthread_condattr_destroy(pointerof(attributes))
    end

    def signal : Nil
      ret = LibC.pthread_cond_signal(self)
      raise RuntimeError.from_os_error("pthread_cond_signal", Errno.new(ret)) unless ret == 0
    end

    def broadcast : Nil
      ret = LibC.pthread_cond_broadcast(self)
      raise RuntimeError.from_os_error("pthread_cond_broadcast", Errno.new(ret)) unless ret == 0
    end

    def wait(mutex : Thread::Mutex) : Nil
      ret = LibC.pthread_cond_wait(self, mutex)
      raise RuntimeError.from_os_error("pthread_cond_wait", Errno.new(ret)) unless ret == 0
    end

    def wait(mutex : Thread::Mutex, time : Time::Span, & : ->)
      ret =
        {% if flag?(:darwin) %}
          ts = uninitialized LibC::Timespec
          ts.tv_sec = time.to_i
          ts.tv_nsec = time.nanoseconds

          LibC.pthread_cond_timedwait_relative_np(self, mutex, pointerof(ts))
        {% else %}
          LibC.clock_gettime(LibC::CLOCK_MONOTONIC, out ts)
          ts.tv_sec += time.to_i
          ts.tv_nsec += time.nanoseconds

          if ts.tv_nsec >= 1_000_000_000
            ts.tv_sec += 1
            ts.tv_nsec -= 1_000_000_000
          end

          LibC.pthread_cond_timedwait(self, mutex, pointerof(ts))
        {% end %}

      case errno = Errno.new(ret)
      when .none?
        # normal resume from #signal or #broadcast
      when Errno::ETIMEDOUT
        yield
      else
        raise RuntimeError.from_os_error("pthread_cond_timedwait", errno)
      end
    end

    def finalize
      ret = LibC.pthread_cond_destroy(self)
      raise RuntimeError.from_os_error("pthread_cond_broadcast", Errno.new(ret)) unless ret == 0
    end

    def to_unsafe
      pointerof(@cond)
    end
  end
end
