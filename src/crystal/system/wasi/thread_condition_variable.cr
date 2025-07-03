# TODO: Implement
class Thread
  class ConditionVariable
    def signal : Nil
    end

    def broadcast : Nil
    end

    def wait(mutex : Thread::Mutex) : Nil
    end

    def wait(mutex : Thread::Mutex, time : Time::Span, &)
    end
  end
end
