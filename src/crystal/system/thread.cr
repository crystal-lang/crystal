# :nodoc:
class Thread
  # Creates and starts a new system thread.
  # def initialize(&proc : ->)

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  # def initialize

  # Suspends the current thread until this thread terminates.
  # def join : Nil

  # Returns the Fiber representing the thread's main stack.
  # def main_fiber

  # Yields the thread.
  # def self.yield : Nil

  # Returns the Thread object associated to the running system thread.
  # def self.current : Thread

  # Associates the Thread object to the running system thread.
  # def self.current=(thread : Thread)
end

require "./thread_linked_list"

{% if flag?(:unix) %}
  require "./unix/pthread"
  require "./unix/pthread_condition_variable"
{% elsif flag?(:win32) %}
  require "./win32/thread"
{% else %}
  {% raise "thread not supported" %}
{% end %}
