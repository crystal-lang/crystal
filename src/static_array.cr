require "enumerable"

struct StaticArray(T, N)
  include Enumerable(T)

  def each
    N.times do |i|
      yield buffer[i]
    end
  end

  def [](index : Int)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexOutOfBounds.new
    end

    buffer[index]
  end

  def []=(index : Int, value : T)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexOutOfBounds.new
    end

    buffer[index] = value
  end

  def length
    N
  end

  def buffer
    pointerof(@buffer)
  end

  def to_s
    String.build do |str|
      str << "["
      each_with_index do |elem, i|
        str << ", " if i > 0
        str << elem.inspect
      end
      str << "]"
    end
  end
end
