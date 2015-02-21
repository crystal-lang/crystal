struct Pointer(T)
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

  def copy_from(source : Pointer(T), count : Int)
    Intrinsics.memcpy(self as Void*, source as Void*, (count * sizeof(T)).to_u32, 0_u32, false)
    self
  end

  def copy_to(target : Pointer(T), count : Int)
    target.copy_from(self, count)
  end

  def move_from(source : Pointer(T), count : Int)
    Intrinsics.memmove(self as Void*, source as Void*, (count * sizeof(T)).to_u32, 0_u32, false)
    self
  end

  def move_to(target : Pointer(T), count : Int)
    target.move_from(self, count)
  end

  def memcmp(other : Pointer(T), count : Int)
    LibC.memcmp(self as Void*, (other as Void*), LibC::SizeT.cast(count * sizeof(T)))
  end

  def swap(i, j)
    self[i], self[j] = self[j], self[i]
  end

  def_hash address

  def to_s(io : IO)
    io << "Pointer("
    io << T.to_s
    io << ")"
    if address == 0
      io << ".null"
    else
      io << "@"
      address.to_s(16, io)
    end
  end

  def realloc(size : Int)
    realloc(size.to_u64)
  end

  def shuffle!(size : Int)
    (size - 1).downto(1) do |i|
      j = rand(i + 1)
      swap(i, j)
    end
    self
  end

  def map!(size : Int)
    size.times do |i|
      self[i] = yield self[i]
    end
  end

  def self.null
    new 0_u64
  end

  def self.malloc(size : Int)
    if size < 0
      raise ArgumentError.new("negative Pointer#malloc size")
    end

    malloc(size.to_u64)
  end

  def self.malloc(size : Int, value : T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = value }
    ptr
  end

  def self.malloc(size : Int)
    ptr = Pointer(typeof(yield 1)).malloc(size)
    size.times { |i| ptr[i] = yield i }
    ptr
  end

  def self.malloc_one(value : T)
    ptr = Pointer(T).malloc(1)
    ptr.value = value
    ptr
  end

  def appender
    PointerAppender.new(self)
  end

  def to_slice(length)
    Slice.new(self, length)
  end
end

struct PointerAppender(T)
  def initialize(@pointer : Pointer(T))
    @start = @pointer
  end

  def <<(value : T)
    @pointer.value = value
    @pointer += 1
  end

  def count
    @pointer - @start
  end

  def pointer
    @pointer
  end
end
