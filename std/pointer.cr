require "comparable"

class Pointer(T)
  include Comparable

  def nil?
    address == 0
  end

  def -(other : Int)
    self + (-other)
  end

  def <=>(other : self)
    address - other.address
  end

  def ==(other)
    false
  end

  def [](offset)
    (self + offset).value
  end

  def []=(offset, value : T)
    (self + offset).value = value
  end

  def memcpy(source : Pointer(T), count : Int)
    while (count -= 1) >= 0
      self[count] = source[count]
    end
    self
  end

  def memmove(source : Pointer(T), count : Int)
    if source.address < address
      memcpy(source, count)
    else
      count.times do |i|
        self[i] = source[i]
      end
    end
    self
  end

  def memcmp(other : Pointer(T), count : Int)
    count.times do |i|
      return false unless self[i] == other[i]
    end
    true
  end

  def map(times, &block : T -> U)
    Array(U).new(times) { |i| yield self[i] }
  end

  def self.malloc(size : Int, value : T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = value }
    ptr
  end

  def self.malloc(size : Int, &block : Int -> T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = yield i }
    ptr
  end
end