require "./thread_mutex"

# :nodoc:
class Thread
  # :nodoc:
  #
  # Thread-safe doubly linked list of `T` objects that must implement
  # `#previous : T?` and `#next : T?` methods.
  class LinkedList(T)
    @mutex = Thread::Mutex.new
    @head : T?
    @tail : T?

    # Iterates the list without acquiring the lock, to avoid a deadlock in
    # stop-the-world situations, where a paused thread could have acquired the
    # lock to push/delete a node, while still being "safe" to iterate (but only
    # during a stop-the-world).
    def unsafe_each(&) : Nil
      node = @head

      while node
        yield node
        node = node.next
      end
    end

    # Safely iterates the list.
    def each(&) : Nil
      @mutex.synchronize do
        unsafe_each { |node| yield node }
      end
    end

    # Appends a node to the tail of the list. The operation is thread-safe.
    #
    # There are no guarantees that a node being pushed will be iterated by
    # `#unsafe_each` until the method has returned.
    def push(node : T) : Nil
      @mutex.synchronize do
        node.previous = nil

        if tail = @tail
          node.previous = tail
          @tail = tail.next = node
        else
          @head = @tail = node
        end
      end
    end

    # Removes a node from the tail of the list. The operation is thread-safe.
    def pop? : T | Nil
      @mutex.synchronize do
        if node = @tail
          unsafe_delete(node)
          node
        end
      end
    end

    # Removes a node from the head of the list. The operation is thread-safe.
    def shift? : T | Nil
      @mutex.synchronize do
        if node = @head
          unsafe_delete(node)
          node
        end
      end
    end

    # Removes a node from the list. The operation is thread-safe.
    #
    # There are no guarantees that a node being deleted won't be iterated by
    # `#unsafe_each` until the method has returned.
    def delete(node : T) : Nil
      @mutex.synchronize do
        unsafe_delete(node)
      end
    end

    # Identical to `#delete` but returns true if the node was unlinked from the
    # list, and false otherwise.
    def delete?(node : T) : Bool
      @mutex.synchronize do
        unsafe_delete(node)
      end
    end

    private def unsafe_delete(node)
      previous = node.previous
      _next = node.next

      if previous
        node.previous = nil
        previous.next = _next
      else
        @head = _next
      end

      if _next
        node.next = nil
        _next.previous = previous
      else
        @tail = previous
      end

      !previous.nil? || !_next.nil?
    end
  end
end
