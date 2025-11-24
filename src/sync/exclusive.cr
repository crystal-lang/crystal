require "./mutex"

module Sync
  # Safely share a value `T` across fibers and execution contexts using a
  # `Mutex`, so only one critical section can access the value at any time.
  #
  # For example:
  #
  # ```
  # require "sync/exclusive"
  #
  # class Queue
  #   @@running : Sync::Exclusive.new([] of Queue)
  #
  #   def self.on_started(queue)
  #     @@running.lock(&.push(queue))
  #   end
  #
  #   def self.on_stopped(queue)
  #     @@running.lock(&.delete(queue))
  #   end
  #
  #   def self.each(&)
  #     @@running.lock do |list|
  #       list.each { |queue| yield queue }
  #     end
  #   end
  # end
  # ```
  #
  # Consider an `Exclusive(T)` if your workload mostly needs to own the value,
  # and most, if not all, critical sections need to mutate the inner state of
  # the value for example.
  class Exclusive(T)
    include Lockable

    {% if compare_versions(Crystal::VERSION, "1.12.0") >= 0 %}
      @lock = uninitialized ReferenceStorage(Mutex)
    {% else %}
      @lock : Mutex
    {% end %}

    def initialize(@value : T, type : Type = :checked)
      {% if compare_versions(Crystal::VERSION, "1.12.0") >= 0 %}
        @lock = uninitialized ReferenceStorage(Mutex)
        Mutex.unsafe_construct(pointerof(@lock), type)
      {% else %}
        @lock = Mutex.new(type)
      {% end %}
    end

    private def lock : Mutex
      {% if compare_versions(Crystal::VERSION, "1.12.0") >= 0 %}
        @lock.to_reference
      {% else %}
        @lock
      {% end %}
    end

    # Locks the mutex and yields the value. The lock is released before
    # returning.
    #
    # The value is owned for the duration of the block, and can be safely
    # mutated.
    #
    # WARNING: The value musn't be retained and accessed after the block has
    # returned.
    def lock(& : T -> U) : U forall U
      lock.synchronize { yield @value }
    end

    # Locks the mutex, yields the value and eventually replaces the value with
    # the one returned by the block. The lock is released before returning.
    #
    # The current value is now owned: it can be safely retained and mutated even
    # after the block returned.
    #
    # WARNING: The new value musn't be retained and accessed after the block has
    # returned.
    def replace(& : T -> T) : Nil
      lock.synchronize { @value = yield @value }
    end

    # Locks the mutex and returns the value. Unlocks before returning.
    #
    # Always acquires the lock, so reading the value is synchronized in relation
    # with the other methods. However, safely accessing the returned value
    # entirely depends on the safety of `T`.
    #
    # Prefer `#lock(&.dup)` or `#lock(&.clone)` to get a shallow or deep copy of
    # the value instead.
    #
    # WARNING: Breaks the mutual exclusion guarantee since the returned value
    # outlives the lock, the value can be accessed concurrently to the
    # synchronized methods.
    def get : T
      lock.synchronize { @value }
    end

    # Locks the mutex and sets the value. Unlocks the mutex before returning.
    #
    # Always acquires and releases the lock, so writing the value is always
    # synchronized with the other methods.
    def set(value : T) : Nil
      lock.synchronize { @value = value }
    end

    # Returns the value without any synchronization.
    #
    # WARNING: Breaks the mutual exclusion constraint! Should only be called
    # after acquiring the lock.
    def unsafe_get : T
      @value
    end

    # Sets the value without any synchronization.
    #
    # WARNING: Breaks the mutual exclusion constraint! Should only be called
    # after acquiring the lock.
    def unsafe_set(@value : T) : T
    end

    protected def wait(cv : Pointer(CV)) : Nil
      lock.wait(cv)
    end
  end
end
