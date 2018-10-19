class Fiber
  # :nodoc:
  class StackPool
    def initialize
      @deque = Deque(Void*).new
      @mutex = Thread::Mutex.new
    end

    # Removes and frees at most *count* stacks from the top of the list,
    # returning memory to the operating system.
    def collect(count = lazy_size / 2)
      count.times do
        if stack = @mutex.synchronize { @deque.shift? }
          LibC.munmap(stack, Fiber::STACK_SIZE)
        else
          return
        end
      end
    end

    # Removes a stack from the bottom of the list.
    def pop?
      @mutex.synchronize { @deque.pop? }
    end

    # Appends a stack to the bottom of the list.
    def <<(stack)
      @mutex.synchronize { @deque.push(stack) }
    end

    # Returns the approximated size of the pool. It may be equal or slightly
    # bigger or smaller than the actual size.
    def lazy_size
      @deque.size
    end
  end
end
