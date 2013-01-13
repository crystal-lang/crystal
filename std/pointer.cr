class Pointer
  def -(other : Int)
    self + (-other)
  end

  def ==(other : Pointer)
    address == other.address
  end

  def ==(other)
    false
  end

  def [](offset)
    (self + offset).value
  end

  def []=(offset, value)
    (self + offset).value = value
  end

  def map(times)
    Array.new(times) { |i| yield self[i] }
  end

  def self.malloc(size : Int, value)
    ptr = malloc(size)
    size.times { |i| ptr[i] = value }
    ptr
  end

  def self.malloc(size : Int)
    ptr = malloc(size)
    size.times { |i| ptr[i] = yield i }
    ptr
  end
end