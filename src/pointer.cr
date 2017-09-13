require "c/string"

# A typed pointer to some memory.
#
# This is the only unsafe type in Crystal. If you are using a pointer, you are writing
# unsafe code because a pointer doesn't know where it's pointing to nor how much memory
# starting from it is valid. However, pointers make it possible to interface with C and
# to implement efficient data structures. For example, both `Array` and `Hash` are
# implemented using pointers.
#
# You can obtain pointers in four ways: `#new`, `#malloc`, `pointerof` and by calling a C
# function that returns a pointer.
#
# `pointerof(x)`, where *x* is a variable or an instance variable, returns a pointer to
# that variable:
#
# ```
# x = 1
# ptr = pointerof(x)
# ptr.value = 2
# x # => 2
# ```
#
# Note that a pointer is *falsey* if it's null (if it's address is zero).
#
# When calling a C function that expects a pointer you can also pass `nil` instead of using
# `Pointer.null` to construct a null pointer.
#
# For a safe alternative, see `Slice`, which is a pointer with a size and with bounds checking.
struct Pointer(T)
  # Unsafe wrapper around a `Pointer` that allows to write values to
  # it while advancing the location and keeping track of how many elements
  # were written.
  #
  # See also: `Pointer#appender`.
  struct Appender(T)
    def initialize(@pointer : Pointer(T))
      @start = @pointer
    end

    def <<(value : T)
      @pointer.value = value
      @pointer += 1
    end

    def size
      @pointer - @start
    end

    def pointer
      @pointer
    end
  end

  include Comparable(self)

  # Returns `true` if this pointer's address is zero.
  #
  # ```
  # a = 1
  # pointerof(a).null? # => false
  #
  # b = Pointer(Int32).new(0)
  # b.null? # => true
  # ```
  def null?
    address == 0
  end

  # Returns a new pointer whose address is this pointer's address incremented by `other * sizeof(T)`.
  #
  # ```
  # ptr = Pointer(Int32).new(1234)
  # ptr.address # => 1234
  #
  # # An Int32 occupies four bytes
  # ptr2 = ptr + 1
  # ptr2.address # => 1238
  # ```
  def +(other : Int)
    self + other.to_i64
  end

  # Returns a new pointer whose address is this pointer's address decremented by `other * sizeof(T)`.
  #
  # ```
  # ptr = Pointer(Int32).new(1234)
  # ptr.address # => 1234
  #
  # # An Int32 occupies four bytes
  # ptr2 = ptr - 1
  # ptr2.address # => 1230
  # ```
  def -(other : Int)
    self + (-other)
  end

  # Returns -1, 0 or 1 if this pointer's address is less, equal or greater than *other*'s address,
  # respectively.
  #
  # See also: `Object#<=>`.
  def <=>(other : self)
    address <=> other.address
  end

  # Gets the value pointed at this pointer's address plus `offset * sizeof(T)`.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| i + 10 }
  # ptr[0] # => 10
  # ptr[1] # => 11
  # ptr[2] # => 12
  # ptr[3] # => 13
  # ```
  def [](offset)
    (self + offset).value
  end

  # Sets the value pointed at this pointer's address plus `offset * sizeof(T)`.
  #
  # ```
  # ptr = Pointer(Int32).malloc(4) # [0, 0, 0, 0]
  # ptr[1] = 42
  #
  # ptr2 = ptr + 1
  # ptr2.value # => 42
  # ```
  def []=(offset, value : T)
    (self + offset).value = value
  end

  # Copies *count* elements from *source* into `self`.
  # If *source* and `self` overlap, behaviour is undefined.
  # Use `#move_from` if they overlap (slower but always works).
  #
  # ```
  # ptr1 = Pointer.malloc(4) { |i| i + 1 }  # [1, 2, 3, 4]
  # ptr2 = Pointer.malloc(4) { |i| i + 11 } # [11, 12, 13, 14]
  #
  # # ptr2 -> [11, 12, 13, 14]
  # #          ^---^           <- copy this
  # # ptr1 -> [1,  2,  3,  4]
  # #          ^---^           <- here
  # ptr1.copy_from(ptr2, 2)
  # ptr1[0] # => 11
  # ptr1[1] # => 12
  # ptr1[2] # => 3
  # ptr1[3] # => 4
  # ```
  def copy_from(source : Pointer(T), count : Int)
    source.copy_to(self, count)
  end

  # :nodoc:
  def copy_from(source : Pointer(NoReturn), count : Int)
    raise ArgumentError.new("Negative count") if count < 0

    # We need this overload for cases when we have a pointer to unreachable
    # data, like when doing Tuple.new.to_a
    self
  end

  # Copies *count* elements from `self` into *target*.
  # If `self` and *target* overlap, behaviour is undefined.
  # Use `#move_to` if they overlap (slower but always works).
  #
  # ```
  # ptr1 = Pointer.malloc(4) { |i| i + 1 }  # [1, 2, 3, 4]
  # ptr2 = Pointer.malloc(4) { |i| i + 11 } # [11, 12, 13, 14]
  #
  # # ptr1 -> [1,  2,  3,  4]
  # #          ^---^           <- copy this
  # # ptr2 -> [11, 12, 13, 14]
  # #          ^---^           <- here
  # ptr1.copy_to(ptr2, 2)
  # ptr2[0] # => 1
  # ptr2[1] # => 2
  # ptr2[2] # => 13
  # ptr2[3] # => 14
  # ```
  def copy_to(target : Pointer, count : Int)
    target.copy_from_impl(self, count)
  end

  # Copies *count* elements from *source* into `self`.
  # *source* and `self` may overlap; the copy is always done in a non-destructive manner.
  #
  # ```
  # ptr1 = Pointer.malloc(4) { |i| i + 1 } # ptr1 -> [1, 2, 3, 4]
  # ptr2 = ptr1 + 1                        #             ^--------- ptr2
  #
  # # [1, 2, 3, 4]
  # #  ^-----^       <- copy this
  # #     ^------^   <- here
  # ptr2.move_from(ptr1, 3)
  #
  # ptr1[0] # => 1
  # ptr1[1] # => 1
  # ptr1[2] # => 2
  # ptr1[3] # => 3
  # ```
  def move_from(source : Pointer(T), count : Int)
    source.move_to(self, count)
  end

  # :nodoc:
  def move_from(source : Pointer(NoReturn), count : Int)
    raise ArgumentError.new("Negative count") if count < 0

    # We need this overload for cases when we have a pointer to unreachable
    # data, like when doing Tuple.new.to_a
    self
  end

  # Copies *count* elements from `self` into *source*.
  # *source* and `self` may overlap; the copy is always done in a non-destructive manner.
  #
  # ```
  # ptr1 = Pointer.malloc(4) { |i| i + 1 } # ptr1 -> [1, 2, 3, 4]
  # ptr2 = ptr1 + 1                        #             ^--------- ptr2
  #
  # # [1, 2, 3, 4]
  # #  ^-----^       <- copy this
  # #     ^------^   <- here
  # ptr1.move_to(ptr2, 3)
  #
  # ptr1[0] # => 1
  # ptr1[1] # => 1
  # ptr1[2] # => 2
  # ptr1[3] # => 3
  # ```
  def move_to(target : Pointer, count : Int)
    target.move_from_impl(self, count)
  end

  # We use separate method in which we make sure that `source`
  # is never a union of pointers. This is guaranteed because both
  # copy_from/move_from/copy_to/move_to reverse self and caller,
  # and so if either self or the arguments are unions a dispatch
  # will happen and unions will disappear.
  protected def copy_from_impl(source : Pointer(T), count : Int)
    raise ArgumentError.new("Negative count") if count < 0

    if self.class == source.class
      Intrinsics.memcpy(self.as(Void*), source.as(Void*), bytesize(count), 0_u32, false)
    else
      while (count -= 1) >= 0
        self[count] = source[count]
      end
    end
    self
  end

  protected def move_from_impl(source : Pointer(T), count : Int)
    raise ArgumentError.new("Negative count") if count < 0

    if self.class == source.class
      Intrinsics.memmove(self.as(Void*), source.as(Void*), bytesize(count), 0_u32, false)
    else
      if source.address < address
        copy_from source, count
      else
        count.times do |i|
          self[i] = source[i]
        end
      end
    end
    self
  end

  # Compares *count* elements from this pointer and *other*, byte by byte.
  #
  # Returns 0 if both pointers point to the same sequence of *count* bytes. Otherwise
  # returns the difference between the first two differing bytes (treated as UInt8).
  #
  # ```
  # ptr1 = Pointer.malloc(4) { |i| i + 1 }  # [1, 2, 3, 4]
  # ptr2 = Pointer.malloc(4) { |i| i + 11 } # [11, 12, 13, 14]
  #
  # ptr1.memcmp(ptr2, 4) # => -10
  # ptr2.memcmp(ptr1, 4) # => 10
  # ptr1.memcmp(ptr1, 4) # => 0
  # ```
  def memcmp(other : Pointer(T), count : Int)
    LibC.memcmp(self.as(Void*), (other.as(Void*)), (count * sizeof(T)))
  end

  # Swaps the contents pointed at the offsets *i* and *j*.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| i + 1 }
  # ptr[2] # => 3
  # ptr[3] # => 4
  # ptr.swap(2, 3)
  # ptr[2] # => 4
  # ptr[3] # => 3
  # ```
  def swap(i, j)
    self[i], self[j] = self[j], self[i]
  end

  # Returns the address of this pointer.
  #
  # ```
  # ptr = Pointer(Int32).new(1234)
  # ptr.hash # => 1234
  # ```
  def_hash address

  # Appends a string representation of this pointer to the given `IO`,
  # including its type and address in hexadecimal.
  #
  # ```
  # ptr1 = Pointer(Int32).new(1234)
  # ptr1.to_s # => "Pointer(Int32)@0x4d2"
  #
  # ptr2 = Pointer(Int32).new(0)
  # ptr2.to_s # => "Pointer(Int32).null"
  # ```
  def to_s(io : IO)
    io << "Pointer("
    io << T.to_s
    io << ")"
    if address == 0
      io << ".null"
    else
      io << "@0x"
      address.to_s(16, io)
    end
  end

  # Tries to change the size of the allocation pointed to by this pointer to *size*,
  # and returns that pointer.
  #
  # Since the space after the end of the block may be in use, realloc may find it
  # necessary to copy the block to a new address where more free space is available.
  # The value of realloc is the new address of the block.
  # If the block needs to be moved, realloc copies the old contents.
  #
  # Remember to always assign the value of realloc.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| i + 1 } # [1, 2, 3, 4]
  # ptr = ptr.realloc(8)
  # ptr # [1, 2, 3, 4, 0, 0, 0, 0]
  # ```
  def realloc(size : Int)
    if size < 0
      raise ArgumentError.new("Negative size")
    end

    realloc(size.to_u64)
  end

  # Shuffles *count* consecutive values pointed by this pointer.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| i + 1 } # [1, 2, 3, 4]
  # ptr.shuffle!(4)
  # ptr # [3, 4, 1, 2]
  # ```
  def shuffle!(count : Int, random = Random::DEFAULT)
    (count - 1).downto(1) do |i|
      j = random.rand(i + 1)
      swap(i, j)
    end
    self
  end

  # Sets *count* consecutive values pointed by this pointer to the
  # values returned by the block.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| i + 1 } # [1, 2, 3, 4]
  # ptr.map!(4) { |value| value * 2 }
  # ptr # [2, 4, 6, 8]
  # ```
  def map!(count : Int)
    count.times do |i|
      self[i] = yield self[i]
    end
  end

  # Like `map!`, but yield 2 arugments, the element and it's index
  def map_with_index!(count : Int, &block)
    count.times do |i|
      self[i] = yield self[i], i
    end
    self
  end

  # Returns a pointer whose memory address is zero. This doesn't allocate memory.
  #
  # When calling a C function you can also pass `nil` instead of constructing a
  # null pointer with this method.
  #
  # ```
  # ptr = Pointer(Int32).null
  # ptr.address # => 0
  # ```
  def self.null
    new 0_u64
  end

  # Returns a pointer that points to the given memory address. This doesn't allocate memory.
  #
  # ```
  # ptr = Pointer(Int32).new(5678)
  # ptr.address # => 5678
  # ```
  def self.new(address : Int)
    new address.to_u64
  end

  # Allocates `size * sizeof(T)` bytes from the system's heap initialized
  # to zero and returns a pointer to the first byte from that memory.
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # # Allocate memory for an Int32: 4 bytes
  # ptr = Pointer(Int32).malloc
  # ptr.value # => 0
  #
  # # Allocate memory for 10 Int32: 40 bytes
  # ptr = Pointer(Int32).malloc(10)
  # ptr[0] # => 0
  # # ...
  # ptr[9] # => 0
  # ```
  def self.malloc(size : Int = 1)
    if size < 0
      raise ArgumentError.new("Negative Pointer#malloc size")
    end

    malloc(size.to_u64)
  end

  # Allocates `size * sizeof(T)` bytes from the system's heap initialized
  # to *value* and returns a pointer to the first byte from that memory.
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # # An Int32 occupies 4 bytes, so here we are requesting 8 bytes
  # # initialized to the number 42
  # ptr = Pointer.malloc(2, 42)
  # ptr[0] # => 42
  # ptr[1] # => 42
  # ```
  def self.malloc(size : Int, value : T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = value }
    ptr
  end

  # Allocates `size * sizeof(T)` bytes from the system's heap initialized
  # to the value returned by the block (which is invoked once with each index in the range `0...size`)
  # and returns a pointer to the first byte from that memory.
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # # An Int32 occupies 4 bytes, so here we are requesting 16 bytes.
  # # i is an index in the range 0 .. 3
  # ptr = Pointer.malloc(4) { |i| i + 10 }
  # ptr[0] # => 10
  # ptr[1] # => 11
  # ptr[2] # => 12
  # ptr[3] # => 13
  # ```
  def self.malloc(size : Int, &block : Int32 -> T)
    ptr = Pointer(T).malloc(size)
    size.times { |i| ptr[i] = yield i }
    ptr
  end

  # Returns a `Pointer::Appender` for this pointer.
  def appender
    Pointer::Appender.new(self)
  end

  # Returns a `Slice` that points to this pointer and is bounded by the given *size*.
  #
  # ```
  # ptr = Pointer.malloc(6) { |i| i + 10 } # [10, 11, 12, 13, 14, 15]
  # slice = ptr.to_slice(4)                # => Slice[10, 11, 12, 13]
  # slice.class                            # => Slice(Int32)
  # ```
  def to_slice(size)
    Slice.new(self, size)
  end

  # Clears (sets to "zero" bytes) a number of values pointed by this pointer.
  #
  # ```
  # ptr = Pointer.malloc(6) { |i| i + 10 } # [10, 11, 12, 13, 14, 15]
  # ptr.clear(3)
  # ptr.to_slice(6) # => Slice[0, 0, 0, 13, 14, 15]
  # ```
  def clear(count = 1)
    Intrinsics.memset(self.as(Void*), 0_u8, bytesize(count), 0_u32, false)
  end

  def clone
    self
  end

  private def bytesize(count)
    {% if flag?(:bits64) %}
      count.to_u64 * sizeof(T)
    {% else %}
      if count > UInt32::MAX
        raise ArgumentError.new("Given count is bigger than UInt32::MAX")
      end

      count.to_u32 * sizeof(T)
    {% end %}
  end
end
