require "comparable"

class Pointer(T)
  include Comparable(self)

  def nil?
    address == 0
  end

  def +(other : Int)
    self + other.to_i64
  end

  def -(other : Int)
    self + (-other)
  end

  def <=>(other : self)
    address <=> other.address
  end

  def [](offset)
    (self + offset).value
  end

  def []=(offset, value : T)
    (self + offset).value = value
  end

  def memcpy(source : Pointer(T), count : Int)
    Intrinsics.memcpy(self as Void*, source as Void*, (count * sizeof(T)).to_u32, 0_u32, false)
    self
  end

  def memmove(source : Pointer(T), count : Int)
    Intrinsics.memmove(self as Void*, source as Void*, (count * sizeof(T)).to_u32, 0_u32, false)
    self
  end

  def memcmp(other : Pointer(T), count : Int)
    C.memcmp(self as Void*, other as Void*, (count * sizeof(T)).to_sizet) == 0
  end

  def swap(i, j)
    self[i], self[j] = self[j], self[i]
  end

  def hash
    address.hash
  end

  def to_s
    "Pointer(#{T})@#{address.to_s(16)}"
  end

  def each(count)
    count.times do |i|
      yield self[i]
    end
  end

  def map(count, &block : T -> U)
    Array(U).new(count) { |i| yield self[i] }
  end

  def to_a(length)
    map(length) { |elem| elem }
  end

  def index(value : T, length)
    length.times do |i|
      return i if self[i] == value
    end
    -1
  end

  def realloc(size : Int)
    realloc(size.to_u64)
  end

  def self.malloc(size : Int)
    malloc(size.to_u64)
  end

  def self.malloc(size : Int, value : T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = value }
    ptr
  end

  def self.malloc(size : Int, &block : Int32 -> T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = yield i }
    ptr
  end
end
