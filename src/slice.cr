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

  def self.new(length : Int32, value : T)
    new(length) { value }
  end

  def +(offset : Int)
    unless 0 <= offset <= length
      raise IndexOutOfBounds.new
    end

    Slice.new(@pointer + offset, @length - offset)
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
    unless 0 <= start <= @length
      raise IndexOutOfBounds.new
    end

    unless 0 <= count <= @length - start
      raise IndexOutOfBounds.new
    end

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

  def pointer(length)
    unless 0 <= length <= @length
      raise IndexOutOfBounds.new
    end

    @pointer
  end

  def copy_from(source : Pointer(T), count)
    pointer(count).copy_from(source, count)
  end

  def copy_to(target : Pointer(T), count)
    pointer(count).copy_to(target, count)
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
end
