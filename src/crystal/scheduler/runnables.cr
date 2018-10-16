# :nodoc:
class Crystal::Scheduler
  # :nodoc:
  #
  # Crystal only accepts simple primitives as `T` for `Atomic(T)`. This struct
  # wraps a 64-bit struct as an `Atomic(UInt64)` and transparently casts from
  # `T` and `UInt64`.
  struct AtomicRef8(T)
    def initialize(value : T)
      # TODO: raise a compile-time error unless sizeof(T) == 8
      @atomic = Atomic(UInt64).new(value.unsafe_as(UInt64))
    end

    def get : T
      @atomic.get.unsafe_as(T)
    end

    def set(value : T) : Nil
      @atomic.set(value.unsafe_as(UInt64))
    end

    def compare_and_set(cmp : T, value : T) : Bool
      _, success = @atomic.compare_and_set(cmp.unsafe_as(UInt64), value.unsafe_as(UInt64))
      success
    end
  end

  # :nodoc:
  #
  # Thread-safe non-blocking queue for work-stealing schedulers.
  #
  # Based on:
  #
  # - "Scheduling Multithreaded Computations by Work Stealing" (2001) by
  #   Nimar S. Arora, Robert D. Blumofe and C. Greg Plaxton.
  #
  # - "Verification of a Concurrent Deque Implementation" (1999) by
  #   Robert D. Blumofe, C. Greg Plaxton and Sandip Ray.
  #
  # The queue has the following assumptions:
  #
  # - Only the owner thread shall push to the bottom of the queue (never
  #   call concurrently);
  #
  # - Only the owner thread shall pop from the bottom of the queue (never called
  #   concurrently, and limited concurrency with pop top);
  #
  # - Only other threads shall pop from the top of the queue (expected to be
  #   called concurrently):
  #
  # - The underlying array is supposed to be infinite. In practice, a scheduler
  #   will only push/pop fibers from the bottom of the queue, which shouldn't
  #   grow the queue much.
  #
  #   Thief schedulers will pop fibers from the top of the queue, digging a hole
  #   at the top of the array, but it will be fixed whenever the queue is
  #   emptied (bottom resets to 0).
  #
  #   This can however be an issue if a thread continuously pushes fibers to a
  #   queue primarily meant to be stolen from (e.g. a dedicated event loop
  #   thread with no scheduler).
  #
  # Refer to the papers above for algorithms, detailed analyzis and proofs.
  class Runnables
    # :nodoc:
    record Age, tag : Int32, top : Int32

    # :nodoc:
    SIZE = Int32::MAX

    def initialize
      @bottom = Atomic(Int32).new(0)
      @age = AtomicRef8(Age).new(Age.new(0, 0))

      # initializes the "infinite" array, using mmap so memory pages will only
      # be allocated when accessed (if ever):
      prot = LibC::PROT_READ | LibC::PROT_WRITE
      flags = LibC::MAP_ANON | LibC::MAP_PRIVATE
      ptr = LibC.mmap(nil, SIZE, prot, flags, -1, 0)
      raise Errno.new("mmap") if ptr == LibC::MAP_FAILED
      @buffer = ptr.as(Fiber*)
    end

    def free
      LibC.munmap(@buffer, SIZE)
    end

    # Pushes an item to the tail of the queue. Not thread-safe and must be
    # called from the thread that owns the queue.
    def push(item : Fiber) : Nil
      bottom = @bottom.get
      @buffer[bottom] = item
      @bottom.set(bottom + 1)
    end

    # Pops an item from the tail of the queue. Not thread-safe and must be
    # called from the thread that owns the queue.
    def pop? : Fiber?
      bottom = @bottom.get
      return if bottom == 0

      bottom -= 1
      @bottom.set(bottom)

      item = @buffer[bottom]
      old_age = @age.get
      return item if bottom > old_age.top

      # queue has been emptied (reset bottom to zero):
      @bottom.set(0)
      new_age = Age.new(old_age.tag + 1, 0)

      if bottom == old_age.top
        if @age.compare_and_set(old_age, new_age)
          return item
        end
      end

      @age.set(new_age)
      nil
    end

    # Pops an item from the head of the queue. Thread-safe and should be called
    # from threads that don't own the queue (i.e. stealing threads).
    def shift? : Fiber?
      old_age = @age.get
      bottom = @bottom.get
      return if bottom <= old_age.top

      item = @buffer[old_age.top]
      new_age = Age.new(old_age.tag, old_age.top + 1)

      if @age.compare_and_set(old_age, new_age)
        return item
      end
    end

    # Lazily returns the queue size. It may be equal or slightly more or less
    # than the actual size.
    def lazy_size : Int32
      bottom = @bottom.get
      age = @age.get
      bottom - age.top
    end
  end
end
