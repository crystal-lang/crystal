# Generational Arena.
#
# The arena allocates objects `T` at a predefined index. The object iself is
# uninitialized (outside of having its memory initialized to zero). The object
# can be allocated and later retrieved using the generation index (Arena::Index)
# that contains both the actual index (Int32) and the generation number
# (UInt32). Deallocating the object increases the generation number, which
# allows the object to be reallocated later on. Trying to retrieve the
# allocation using the generation index will fail if the generation number
# changed (it's a new allocation).
#
# This arena isn't generic as it won't keep a list of free indexes. It assumes
# that something else will maintain the uniqueness of indexes and reuse indexes
# as much as possible instead of growing.
#
# For example this arena is used to hold `Crystal::EventLoop::Polling::PollDescriptor`
# allocations for all the fd in a program, where the fd is used as the index.
# They're unique to the process and the OS always reuses the lowest fd numbers
# before growing.
#
# Thread safety: the memory region is divided in blocks of size BLOCK_BYTESIZE
# allocated in the GC. Pointers are thus never invalidated. Mutating the blocks
# is protected by a mutual exclusion lock. Individual (de)allocations of objects
# are protected with a fine grained lock.
#
# Guarantees: blocks' memory is initialized to zero, which means `T` objects are
# initialized to zero by default, then `#free` will also clear the memory, so
# the next allocation shall be initialized to zero, too.
class Crystal::EventLoop::Polling::Arena(T, BLOCK_BYTESIZE)
  INVALID_INDEX = Index.new(-1, 0)

  struct Index
    def initialize(index : Int32, generation : UInt32)
      @data = (index.to_i64! << 32) | generation.to_u64!
    end

    def initialize(@data : Int64)
    end

    def initialize(data : UInt64)
      @data = data.to_i64!
    end

    # Returns the generation number.
    def generation : UInt32
      @data.to_u32!
    end

    # Returns the actual index.
    def index : Int32
      (@data >> 32).to_i32!
    end

    def to_i64 : Int64
      @data
    end

    def to_u64 : UInt64
      @data.to_u64!
    end

    def valid? : Bool
      @data >= 0
    end
  end

  struct Entry(T)
    @lock = SpinLock.new # protects parallel allocate/free calls
    property? allocated = false
    property generation = 0_u32
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

  @blocks : Slice(Pointer(Entry(T)))
  @capacity : Int32

  def initialize(@capacity : Int32)
    @blocks = Slice(Pointer(Entry(T))).new(1) { allocate_block }
    @mutex = Thread::Mutex.new
  end

  # Allocates the object at *index* unless already allocated, then yields a
  # pointer to the object at *index* and the current generation index to later
  # retrieve and free the allocated object. Eventually returns the generation
  # index.
  #
  # Does nothing if the object has already been allocated and returns `nil`.
  #
  # There are no generational checks.
  # Raises if *index* is out of bounds.
  def allocate_at?(index : Int32, & : (Pointer(T), Index) ->) : Index?
    entry = at(index, grow: true)

    entry.value.@lock.sync do
      return if entry.value.allocated?

      entry.value.allocated = true

      gen_index = Index.new(index, entry.value.generation)
      yield entry.value.pointer, gen_index

      gen_index
    end
  end

  # Same as `#allocate_at?` but raises when already allocated.
  def allocate_at(index : Int32, & : (Pointer(T), Index) ->) : Index?
    allocate_at?(index) { |ptr, idx| yield ptr, idx } ||
      raise RuntimeError.new("#{self.class.name}: already allocated index=#{index}")
  end

  # Yields a pointer to the object previously allocated at *index*.
  #
  # Raises if the object isn't allocated, the generation has changed (i.e. the
  # object has been freed then reallocated) or *index* is out of bounds.
  def get(index : Index, &) : Nil
    at(index) do |entry|
      yield entry.value.pointer
    end
  end

  # Yields a pointer to the object previously allocated at *index* and returns
  # true.
  #
  # Does nothing if the object isn't allocated, the generation has changed or
  # *index* is out of bounds.
  def get?(index : Index, &) : Bool
    at?(index) do |entry|
      yield entry.value.pointer
      return true
    end
    false
  end

  # Yields the object previously allocated at *index* then releases it.
  #
  # Does nothing if the object isn't allocated, the generation has changed or
  # *index* is out of bounds.
  def free(index : Index, &) : Nil
    at?(index) do |entry|
      begin
        yield entry.value.pointer
      ensure
        entry.value.free
      end
    end
  end

  private def at(index : Index, &) : Nil
    entry = at(index.index, grow: false)
    entry.value.@lock.lock

    unless entry.value.allocated? && entry.value.generation == index.generation
      entry.value.@lock.unlock
      raise RuntimeError.new("#{self.class.name}: invalid reference index=#{index.index}:#{index.generation} current=#{index.index}:#{entry.value.generation}")
    end

    begin
      yield entry
    ensure
      entry.value.@lock.unlock
    end
  end

  private def at?(index : Index, &) : Nil
    return unless entry = at?(index.index)

    entry.value.@lock.sync do
      return unless entry.value.allocated?
      return unless entry.value.generation == index.generation

      yield entry
    end
  end

  private def at(index : Int32, grow : Bool) : Pointer(Entry(T))
    raise IndexError.new unless 0 <= index < @capacity

    n, j = index.divmod(entries_per_block)

    if n >= @blocks.size
      raise RuntimeError.new("#{self.class.name}: not allocated index=#{index}") unless grow
      @mutex.synchronize { unsafe_grow(n) if n >= @blocks.size }
    end

    @blocks.to_unsafe[n] + j
  end

  private def at?(index : Int32) : Pointer(Entry(T))?
    return unless 0 <= index < @capacity

    n, j = index.divmod(entries_per_block)

    if block = @blocks[n]?
      block + j
    end
  end

  private def unsafe_grow(n)
    # we manually dup instead of using realloc to avoid parallelism issues, for
    # example fork or another thread trying to iterate after realloc but before
    # we got the time to set @blocks or to allocate the new blocks
    new_size = n + 1
    new_pointer = GC.malloc(new_size * sizeof(Pointer(Entry(T)))).as(Pointer(Pointer(Entry(T))))
    @blocks.to_unsafe.copy_to(new_pointer, @blocks.size)
    @blocks.size.upto(n) { |j| new_pointer[j] = allocate_block }

    @blocks = Slice.new(new_pointer, new_size)
  end

  private def allocate_block
    GC.malloc(BLOCK_BYTESIZE).as(Pointer(Entry(T)))
  end

  # Iterates all allocated objects, yields the actual index as well as the
  # generation index.
  def each_index(&) : Nil
    index = 0

    @blocks.each do |block|
      entries_per_block.times do |j|
        entry = block + j

        if entry.value.allocated?
          yield index, Index.new(index, entry.value.generation)
        end

        index += 1
      end
    end
  end

  private def entries_per_block
    # can't be a constant: can't access a generic when assigning a constant
    BLOCK_BYTESIZE // sizeof(Entry(T))
  end
end
