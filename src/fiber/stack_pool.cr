class Fiber
  # :nodoc:
  class StackPool
    STACK_SIZE = 8 * 1024 * 1024

    def initialize
      @deque = Deque(Void*).new
    end

    # Removes and frees at most *count* stacks from the top of the pool,
    # returning memory to the operating system.
    def collect(count = lazy_size // 2)
      count.times do
        if stack = @deque.shift?
          LibC.munmap(stack, STACK_SIZE)
        else
          return
        end
      end
    end

    # Removes a stack from the bottom of the pool, or allocates a new one.
    def checkout
      stack = @deque.pop? || allocate
      {stack, stack + STACK_SIZE}
    end

    # Appends a stack to the bottom of the pool.
    def release(stack)
      @deque.push(stack)
    end

    # Returns the approximated size of the pool. It may be equal or slightly
    # bigger or smaller than the actual size.
    def lazy_size
      @deque.size
    end

    private def allocate
      flags = LibC::MAP_PRIVATE | LibC::MAP_ANON
      {% if flag?(:openbsd) && !flag?(:"openbsd6.2") %}
        flags |= LibC::MAP_STACK
      {% end %}

      pointer = LibC.mmap(nil, STACK_SIZE, LibC::PROT_READ | LibC::PROT_WRITE, flags, -1, 0)
      raise Errno.new("Cannot allocate new fiber stack") if pointer == LibC::MAP_FAILED

      {% if flag?(:linux) %}
        LibC.madvise(pointer, STACK_SIZE, LibC::MADV_NOHUGEPAGE)
      {% end %}

      LibC.mprotect(pointer, 4096, LibC::PROT_NONE)
      pointer
    end
  end
end
