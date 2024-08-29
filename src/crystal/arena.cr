# OPTIMIZE: can the generation help to avoid the mutation lock (atomic)?
# OPTIMIZE: consider a memory map (mmap, VirtualAlloc) with a maximum capacity
struct Crystal::Arena(T)
  struct Allocation(T)
    property generation = 0_u32
    property? allocated = false
    @object = uninitialized T

    def pointer : Pointer(T)
      pointerof(@object)
    end

    def free : Nil
      @generation &+= 1_u32
      @allocated = false
      pointer.clear(1)
    end
  end

  @buffer : Slice(Allocation(T))

  def initialize
    @lock = SpinLock.new
    @buffer = Pointer(Allocation(T)).malloc(32).to_slice(32)
  end

  private def grow_buffer(capacity)
    buffer = Pointer(Allocation(T)).malloc(capacity).to_slice(capacity)
    buffer.to_unsafe.copy_from(@buffer.to_unsafe, @buffer.size)
    @buffer = buffer
  end

  # Returns a pointer to the object allocated at *gen_idx* (generation index).
  # Raises if the object isn't allocated.
  # Raises if the generation has changed (i.e. the object has been freed then reallocated)
  # Raises if *index* is negative.
  def get(gen_idx : Int64) : Pointer(T)
    index, generation = from_gen_index(gen_idx)

    in_bounds!(index)
    allocation = @buffer.to_unsafe + index

    unless allocation.value.allocated?
      raise RuntimeError.new("#{self.class.name}: object not allocated at index #{index}")
    end

    unless (actual = allocation.value.generation) == generation
      raise RuntimeError.new("#{self.class.name}: object generation changed at index #{index} (#{generation} => #{actual})")
    end

    allocation.value.pointer
  end

  # Yields and allocates the object at *index* unless already allocated.
  # Returns a pointer to the object at *index* and the generation index.
  #
  # There are no generational checks.
  # Raises if *index* is negative.
  def lazy_allocate(index : Int32, &) : {Pointer(T), Int64}
    # fast-path: check if already allocated
    if in_bounds?(index)
      allocation = @buffer.to_unsafe + index

      if allocation.value.allocated?
        return {allocation.value.pointer, to_gen_index(index, allocation)}
      end
    end

    # slow-path: allocate
    @lock.sync do
      if index >= @buffer.size
        # slowest-path: grow the buffer
        grow_buffer(Math.pw2ceil(Math.max(index, @buffer.size * 2)))
      end

      unsafe_allocate(index) do |pointer, gen_index|
        yield pointer, gen_index
      end
    end
  end

  private def unsafe_allocate(index : Int32, &) : {Pointer(T), Int64}
    allocation = @buffer.to_unsafe + index
    pointer = allocation.value.pointer
    gen_index = to_gen_index(index, allocation)

    unless allocation.value.allocated?
      allocation.value.allocated = true
      yield pointer, gen_index
    end

    {pointer, gen_index}
  end

  # Yields the object allocated at *index* then releases it.
  # Does nothing if the object wasn't allocated.
  #
  # Raises if *index* is negative.
  def free(index : Int32, &) : Nil
    return unless in_bounds?(index)

    @lock.sync do
      allocation = @buffer.to_unsafe + index
      return unless allocation.value.allocated?

      yield allocation.value.pointer
      allocation.value.free
    end
  end

  private def in_bounds?(index : Int32) : Bool
    if index.negative?
      raise ArgumentError.new("#{self.class.name}: negative index #{index}")
    else
      index < @buffer.size
    end
  end

  private def in_bounds!(index : Int32) : Nil
    if index.negative?
      raise ArgumentError.new("#{self.class.name}: negative index #{index}")
    elsif index >= @buffer.size
      raise IndexError.new("#{self.class.name}: out of bounds index #{index}")
    end
  end

  # Iterates all allocated objects, yields the actual index as well as the
  # generation index.
  def each(&) : Nil
    ptr = @buffer.to_unsafe

    @buffer.size.times do |index|
      allocation = ptr + index

      if allocation.value.allocated?
        yield index, to_gen_index(index, allocation)
      end
    end
  end

  private def to_gen_index(index : Int32, allocation : Pointer(Allocation(T))) : Int64
    to_gen_index(index, allocation.value.generation)
  end

  private def to_gen_index(index : Int32, generation : UInt32) : Int64
    (index.to_i64! << 32) | generation.to_u64!
  end

  private def from_gen_index(gen_index : Int64) : {Int32, UInt32}
    {(gen_index >> 32).to_i32!, gen_index.to_u32!}
  end
end
