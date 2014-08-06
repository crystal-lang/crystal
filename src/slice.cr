struct Slice(T)
  include Enumerable(T)

  getter length

  def initialize(@pointer : Pointer(T), @length : Int32)
  end

  def self.new(length : Int32)
    pointer = Pointer(T).malloc(length)
    new(pointer, length)
  end

  def self.new(length : Int32)
    pointer = Pointer.malloc(length) { |i| yield i }
    new(pointer, length)
  end

  def +(offset : Int)
    new_length = @length - offset
    if new_length < 0
      raise IndexOutOfBounds.new
    end

    Slice.new(@pointer + offset, new_length)
  end

  def [](index : Int)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexOutOfBounds.new
    end

    @pointer[index]
  end

  def []=(index : Int, value : T)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexOutOfBounds.new
    end

    @pointer[index] = value
  end

  def [](start, count)
    # TODO: validate
    Slice.new(@pointer + start, count)
  end

  def empty?
    @length == 0
  end

  def each
    length.times do |i|
      yield @pointer[i]
    end
  end

  def inspect(io)
    to_s(io)
  end

  def to_s(io)
    io << "["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  def to_unsafe
    @pointer
  end

  def pointer(length = @length)
    unless 0 <= length <= @length
      raise IndexOutOfBounds.new
    end

    @pointer
  end
end
