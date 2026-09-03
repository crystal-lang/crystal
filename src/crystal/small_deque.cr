module Crystal
  # :nodoc:
  # An internal deque type whose storage is backed by a `StaticArray`. The deque
  # capacity is fixed to N and storing more than N elements is an error. Only a
  # subset of `::Deque`'s functionality is defined as needed.
  struct SmallDeque(T, N)
    include Indexable::Mutable(T)

    @start = 0
    @buffer = uninitialized T[N]
    getter size : Int32 = 0

    def unsafe_fetch(index : Int) : T
      index_to_ptr(index).value
    end

    def unsafe_put(index : Int, value : T)
      index_to_ptr(index).value = value
    end

    def <<(value : T)
      check_capacity_for_insert
      unsafe_put(@size, value)
      @size += 1
      self
    end

    def shift(&)
      if @size == 0
        yield
      else
        ptr = index_to_ptr(0)
        value = ptr.value
        ptr.clear
        @size &-= 1
        @start &+= 1
        @start &-= N if @start >= N
        value
      end
    end

    # precondition: 0 <= index <= N
    private def index_to_ptr(index)
      index &+= @start
      index &-= N if index >= N
      @buffer.to_unsafe + index
    end

    private def check_capacity_for_insert
      raise "Out of capacity" if @size >= N
    end
  end
end
