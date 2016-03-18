require "io"

# Similar to `MemoryIO`, but optimized for building a single string.
#
# You should never have to deal with this class. Instead, use `String.build`.
class String::Builder
  include IO

  getter bytesize : Int32
  @capacity : Int32
  @buffer : Pointer(UInt8)
  @finished : Bool

  def initialize(capacity : Int = 64)
    String.check_capacity_in_bounds(capacity)

    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @bytesize = 0
    @capacity = capacity.to_i
    @finished = false
  end

  def self.build(capacity : Int = 64)
    builder = new(capacity)
    yield builder
    builder.to_s
  end

  def self.new(string : String)
    io = new(string.bytesize)
    io << string
    io
  end

  def read(slice : Slice(UInt8))
    raise "Not implemented"
  end

  def write(slice : Slice(UInt8))
    count = slice.size
    new_bytesize = real_bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + real_bytesize, count)
    @bytesize += count

    nil
  end

  def buffer
    @buffer + String::HEADER_SIZE
  end

  def empty?
    @bytesize == 0
  end

  def to_s
    raise "can only invoke 'to_s' once on String::Builder" if @finished
    @finished = true

    write_byte 0_u8

    # Try to reclaim some memory if capacity is bigger than what we need
    real_bytesize = real_bytesize()
    if @capacity > real_bytesize
      resize_to_capacity(real_bytesize)
    end

    header = @buffer as {Int32, Int32, Int32}*
    header.value = {String::TYPE_ID, @bytesize - 1, 0}
    @buffer as String
  end

  private def real_bytesize
    @bytesize + String::HEADER_SIZE
  end

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if real_bytesize == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end
