struct Crystal::Arena(T)
  struct Allocation(T)
    property? allocated = false
    @object = uninitialized T

    def pointer : Pointer(T)
      pointerof(@object)
    end
  end

  @buffer : Slice(Allocation(T))

  def initialize
    @lock = SpinLock.new
    @buffer = allocate_buffer(32)
  end

  private def allocate_buffer(capacity) : Slice(Allocation(T))
    bytesize = sizeof(Allocation(T)) * capacity
    pointer = GC.malloc(bytesize).as(Pointer(Allocation(T)))
    Slice.new(pointer, capacity)
  end

  private def grow_buffer(capacity)
    buffer = allocate_buffer(capacity)
    buffer.to_unsafe.copy_from(@buffer.to_unsafe, @buffer.size)
    @buffer = buffer
  end

  # Returns a pointer to the object allocated at *index*.
  # Returns `nil` if the object isn't allocated.
  # Raises if *index* is negative.
  def get?(index : Int32) : Pointer(T) | Nil
    if in_bounds?(index)
      allocation = @buffer.to_unsafe + index
      allocation.value.pointer if allocation.value.allocated?
    end
  end

  # Yields and allocates the object at *index* if not allocated.
  # Returns a pointer to the object at *index*.
  # Raises if *index* is negative.
  def get_or_allocate(index : Int32, &) : Pointer(T)
    # fast-path: check if already allocated
    if in_bounds?(index)
      allocation = @buffer.to_unsafe + index

      if allocation.value.allocated?
        return allocation.value.pointer
      end
    end

    # slow-path: allocate
    @lock.sync do
      if index >= @buffer.size
        # slowest-path: grow the buffer
        grow_buffer(Math.pw2ceil(Math.max(index, @buffer.size * 2)))
      end

      unsafe_allocate(index) do |pointer|
        yield pointer
      end
    end
  end

  private def unsafe_allocate(index : Int32, &) : Pointer(T)
    allocation = @buffer.to_unsafe + index
    pointer = allocation.value.pointer

    unless allocation.value.allocated?
      allocation.value.allocated = true
      yield pointer
    end

    pointer
  end

  # Releases the object allocated at *index*.
  # Does nothing if the object wasn't allocated.
  # Raises if *index* is negative.
  def free(index : Int32) : Nil
    if in_bounds?(index)
      allocation = @buffer.to_unsafe + index
      allocation.clear(1) if allocation.value.allocated?
    end
  end

  private def in_bounds?(index : Int32) : Bool
    if index.negative?
      raise ArgumentError.new("Negative index")
    else
      index < @buffer.size
    end
  end

  # Yields each allocated index.
  def each_index(&) : Nil
    ptr = @buffer.to_unsafe

    @buffer.size.times do |index|
      yield index if (ptr + index).value.allocated?
    end
  end

  # private def in_bounds?(index)
  #   0 <= index < @buffer.size
  # end
end
