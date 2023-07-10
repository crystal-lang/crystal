class Thread
  class ConditionVariable
    # Creates a new condition variable.
    # def initialize

    # Unblocks one thread that is waiting on `self`.
    # def signal : Nil

    # Unblocks all threads that are waiting on `self`.
    # def broadcast : Nil

    # Causes the calling thread to wait on `self` and unlock the given *mutex*
    # atomically.
    # def wait(mutex : Thread::Mutex) : Nil

    # Causes the calling thread to wait on `self` and unlock the given *mutex*
    # atomically within the given *time* span. Yields to the given block if a
    # timeout occurs.
    # def wait(mutex : Thread::Mutex, time : Time::Span, & : ->)
  end
end

{% if flag?(:wasi) %}
  require "./wasi/thread_condition_variable"
{% elsif flag?(:unix) %}
  require "./unix/pthread_condition_variable"
{% elsif flag?(:win32) %}
  require "./win32/thread_condition_variable"
{% else %}
  {% raise "Thread condition variable not supported" %}
{% end %}
