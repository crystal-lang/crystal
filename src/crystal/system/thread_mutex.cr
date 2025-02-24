class Thread
  class Mutex
    # Creates a new mutex.
    # def initialize

    # Locks the mutex from the current thread.
    # def lock : Nil

    # Tries to lock the mutex and returns `false` if failed.
    # def try_lock : Bool

    # Unlocks the mutex from the current thread.
    # def unlock : Nil

    # Locks the mutex, yields to the block and ensures it unlocks afterwards.
    # def synchronize(&block)
  end
end

{% if flag?(:wasi) %}
  require "./wasi/thread_mutex"
{% elsif flag?(:unix) %}
  require "./unix/pthread_mutex"
{% elsif flag?(:win32) %}
  require "./win32/thread_mutex"
{% else %}
  {% raise "Thread mutex not supported" %}
{% end %}
