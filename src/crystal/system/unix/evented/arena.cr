# Generational Arena.
#
# Allocates a `Slice` of `T` through `mmap`. `T` is supposed to be a struct, so
# it can be embedded right into the memory region.
#
# The arena allocates objects `T` at a predefined index. The object iself is
# uninitialized (outside of having its memory initialized to zero). The object
# can be allocated and later retrieved using the generation index (Int64) that
# contains both the actual index (Int32) and the generation number (UInt32).
# Deallocating the object increases the generation number, which allows the
# object to be reallocated later on. Trying to retrieve the allocation using the
# generation index will fail if the generation number changed (it's a new
# allocation).
#
# This arena isn't generic as it won't keep a list of free indexes. It assumes
# that something else will maintain the uniqueness of indexes and reuse indexes
# as much as possible instead of growing.
#
# For example this arena is used to hold `Crystal::Evented::PollDescriptor`
# allocations for all the fd in a program, where the fd is used as the index.
# They're unique to the process and the OS always reuses the lowest fd numbers
# before growing.
#
# Thread safety: the memory region is pre-allocated (up to capacity) using mmap
# (virtual allocation) and pointers are never invalidated. Individual
# (de)allocations of objects are protected with a fine grained lock.
#
# Guarantees: `mmap` initializes the memory to zero, which means `T` objects are
# initialized to zero by default, then `#free` will also clear the memory, so
# the next allocation shall be initialized to zero, too.
#
# TODO: we could use a growing/shrinking buffer (realloc) though it would
# require a rwlock to borrow accesses during which we can mutate the pointed
# memory, but growing/shrinking would need exclusive write access (it
# reallocates, hence invalidates all pointers); resizing could be delayed and
# thus shouldn't happen often + borrowing accesses should be as quick/small as
# possible.
class Crystal::Evented::Arena(T)
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

  @buffer : Slice(Entry(T))

  {% unless flag?(:preview_mt) %}
    @maximum = 0
  {% end %}

  def initialize(capacity : Int32)
    pointer = self.class.mmap(LibC::SizeT.new(sizeof(Entry(T))) * capacity)
    @buffer = Slice.new(pointer.as(Pointer(Entry(T))), capacity)
  end

  protected def self.mmap(bytesize)
    flags = LibC::MAP_PRIVATE | LibC::MAP_ANON
    prot = LibC::PROT_READ | LibC::PROT_WRITE

    pointer = LibC.mmap(nil, bytesize, prot, flags, -1, 0)
    System.panic("mmap", Errno.value) if pointer == LibC::MAP_FAILED

    {% if flag?(:linux) %}
      LibC.madvise(pointer, bytesize, LibC::MADV_NOHUGEPAGE)
    {% end %}

    pointer
  end

  def finalize
    LibC.munmap(@buffer.to_unsafe, @buffer.bytesize)
  end

  # Returns a pointer to the object allocated at *gen_idx* (generation index).
  #
  # Raises if the object isn't allocated.
  # Raises if the generation has changed (i.e. the object has been freed then reallocated).
  # Raises if *index* is negative.
  def get(gen_idx : Int64) : Pointer(T)
    index, generation = from_gen_index(gen_idx)
    entry = at(index)

    unless entry.value.allocated?
      raise RuntimeError.new("#{self.class.name}: object not allocated at index #{index}")
    end

    unless (actual = entry.value.generation) == generation
      raise RuntimeError.new("#{self.class.name}: object generation changed at index #{index} (#{generation} => #{actual})")
    end

    entry.value.pointer
  end

  # Yields and allocates the object at *index* unless already allocated.
  # Returns a pointer to the object at *index* and the generation index.
  #
  # Permits two threads to allocate the same object in parallel yet only allow
  # one to initialize it; the other one will silently receive the pointer and
  # the generation index.
  #
  # There are no generational checks.
  # Raises if *index* is negative.
  def lazy_allocate(index : Int32, &) : {Pointer(T), Int64}
    entry = at(index)

    entry.value.@lock.sync do
      pointer = entry.value.pointer
      gen_index = to_gen_index(index, entry)

      unless entry.value.allocated?
        {% unless flag?(:preview_mt) %}
          @maximum = index if index > @maximum
        {% end %}

        entry.value.allocated = true
        yield pointer, gen_index
      end

      {pointer, gen_index}
    end
  end

  # Yields the object allocated at *index* then releases it.
  # Does nothing if the object wasn't allocated.
  #
  # Raises if *index* is negative.
  def free(index : Int32, &) : Nil
    return unless entry = at?(index)

    entry.value.@lock.sync do
      return unless entry.value.allocated?

      yield entry.value.pointer
      entry.value.free
    end
  end

  private def at(index : Int32) : Pointer(Entry(T))
    if index.negative?
      raise ArgumentError.new("#{self.class.name}: negative index #{index}")
    end
    if index >= @buffer.size
      raise ArgumentError.new("#{self.class.name}: out of bounds index #{index} >= #{@buffer.size}")
    end
    @buffer.to_unsafe + index
  end

  private def at?(index : Int32) : Pointer(Entry(T))?
    if index.negative?
      raise ArgumentError.new("#{self.class.name}: negative index #{index}")
    end
    if index < @buffer.size
      @buffer.to_unsafe + index
    end
  end

  {% unless flag?(:preview_mt) %}
    # Iterates all allocated objects, yields the actual index as well as the
    # generation index.
    def each(&) : Nil
      pointer = @buffer.to_unsafe

      0.upto(@maximum) do |index|
        entry = pointer + index

        if entry.value.allocated?
          yield index, to_gen_index(index, entry)
        end
      end
    end
  {% end %}

  private def to_gen_index(index : Int32, entry : Pointer(Entry(T))) : Int64
    (index.to_i64! << 32) | entry.value.generation.to_u64!
  end

  private def from_gen_index(gen_index : Int64) : {Int32, UInt32}
    {(gen_index >> 32).to_i32!, gen_index.to_u32!}
  end
end
