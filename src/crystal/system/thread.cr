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

  # Holds the GC thread handler
  property gc_thread_handler : Void* = Pointer(Void).null
end

require "./thread_linked_list"
require "./thread_condition_variable"

{% if flag?(:wasi) %}
  require "./wasi/thread"
{% elsif flag?(:unix) %}
  require "./unix/pthread"
{% elsif flag?(:win32) %}
  require "./win32/thread"
{% else %}
  {% raise "Thread not supported" %}
{% end %}
