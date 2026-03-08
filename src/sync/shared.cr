require "./rw_lock"

module Sync
  # Safely share a value `T` across fibers and execution contexts using a
  # `RWLock` to control when the access to a value can be shared (read-only) or
  # must be exclusive (replace or mutate the value).
  #
  # For example:
  #
  # ```
  # require "sync/shared"
  #
  # class Queue
  #   @@running : Sync::Shared.new([] of Queue)
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
  #     @@running.shared do |list|
  #       list.each { |queue| yield queue }
  #     end
  #   end
  # end
  # ```
  #
  # Consider a `Shared(T)` if your workload mostly consists of immutable reads
  # of the value, with only seldom writes or inner mutations of the value's
  # inner state.
  class Shared(T)
    include Lockable

    {% if compare_versions(Crystal::VERSION, "1.12.0") >= 0 %}
      @lock = uninitialized ReferenceStorage(RWLock)
    {% else %}
      @lock = uninitialized RWLock
    {% end %}

    def initialize(@value : T, type : Type = :checked)
      {% if compare_versions(Crystal::VERSION, "1.12.0") >= 0 %}
        @lock = uninitialized ReferenceStorage(RWLock)
        RWLock.unsafe_construct(pointerof(@lock), type)
      {% else %}
        @lock = RWLock.new(type)
      {% end %}
    end

    private def lock : RWLock
      {% if compare_versions(Crystal::VERSION, "1.12.0") >= 0 %}
        @lock.to_reference
      {% else %}
        @lock
      {% end %}
    end

    # Locks in shared mode and yields the value. The lock is released before
    # returning.
    #
    # The value is owned in shared mode for the duration of the block, and thus
    # shouldn't be mutated for example, unless `T` can be safely mutated (it
    # should be `Sync::Safe`).
    #
    # WARNING: The value musn't be retained and accessed after the block has
    # returned.
    def shared(& : T -> U) : U forall U
      lock.read { yield @value }
    end

    # Locks in exclusive mode and yields the value. The lock is released before
    # returning.
    #
    # The value is owned in exclusive mode for the duration of the block, as
    # such it can be safely mutated.
    #
    # WARNING: The value musn't be retained and accessed after the block has
    # returned.
    def lock(& : T -> U) : U forall U
      lock.write { yield @value }
    end

    # Locks in exclusive mode, yields the current value and eventually replaces
    # the value with the one returned by the block. The lock is released before
    # returning.
    #
    # The current value is now owned: it can be safely retained and mutated even
    # after the block returned.
    #
    # WARNING: The new value musn't be retained and accessed after the block has
    # returned.
    def replace(& : T -> T) : Nil
      lock.write { @value = yield @value }
    end

    # Locks in shared mode and returns the value. Unlocks before returning.
    #
    # Always acquires the lock, so reading the value is synchronized in relation
    # with the other methods. However, safely accessing the returned value
    # entirely depends on the safety of `T`.
    #
    # Prefer `#shared(&.dup)` or `#shared(&.clone)` to get a shallow or deep
    # copy of the value instead.
    #
    # WARNING: Breaks the shared/exclusive guarantees since the returned value
    # outlives the lock, the value can be accessed concurrently to the
    # synchronized methods.
    def get : T
      lock.read { @value }
    end

    # Locks in exclusive mode and sets the value.
    def set(value : T) : Nil
      lock.write { @value = value }
    end

    # Returns the value without any synchronization.
    #
    # WARNING: Breaks the safety constraints! Should only be called after
    # acquiring the exclusive lock.
    def unsafe_get : T
      @value
    end

    # Sets the value without any synchronization.
    #
    # WARNING: Breaks the safety constraints! Should only be called after
    # acquiring the exclusive lock.
    def unsafe_set(@value : T) : T
    end

    protected def wait(cv : Pointer(CV)) : Nil
      lock.wait(cv)
    end
  end
end
