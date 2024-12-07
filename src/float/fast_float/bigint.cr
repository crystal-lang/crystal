require "./float_common"

module Float::FastFloat
  # the limb width: we want efficient multiplication of double the bits in
  # limb, or for 64-bit limbs, at least 64-bit multiplication where we can
  # extract the high and low parts efficiently. this is every 64-bit
  # architecture except for sparc, which emulates 128-bit multiplication.
  # we might have platforms where `CHAR_BIT` is not 8, so let's avoid
  # doing `8 * sizeof(limb)`.
  {% if flag?(:bits64) %}
    alias Limb = UInt64
    LIMB_BITS = 64
  {% else %}
    alias Limb = UInt32
    LIMB_BITS = 32
  {% end %}

  alias LimbSpan = Slice(Limb)

  # number of bits in a bigint. this needs to be at least the number
  # of bits required to store the largest bigint, which is
  # `log2(10**(digits + max_exp))`, or `log2(10**(767 + 342))`, or
  # ~3600 bits, so we round to 4000.
  BIGINT_BITS = 4000
  {% begin %}
    BIGINT_LIMBS = {{ BIGINT_BITS // LIMB_BITS }}
  {% end %}

  # vector-like type that is allocated on the stack. the entire
  # buffer is pre-allocated, and only the length changes.
  # NOTE(crystal): Deviates a lot from the original implementation to reuse
  # `Indexable` as much as possible. Contrast with `Crystal::SmallDeque` and
  # `Crystal::Tracing::BufferIO`
  struct Stackvec(Size)
    include Indexable::Mutable(Limb)

    @data = uninitialized Limb[Size]

    # we never need more than 150 limbs
    @length = 0_u16

    def unsafe_fetch(index : Int) : Limb
      @data.to_unsafe[index]
    end

    def unsafe_put(index : Int, value : Limb) : Limb
      @data.to_unsafe[index] = value
    end

    def size : Int32
      @length.to_i32!
    end

    def to_unsafe : Limb*
      @data.to_unsafe
    end

    def to_slice : LimbSpan
      LimbSpan.new(@data.to_unsafe, @length)
    end

    def initialize
    end

    # create stack vector from existing limb span.
    def initialize(s : LimbSpan)
      try_extend(s)
    end

    # index from the end of the container
    def rindex(index : Int) : Limb
      rindex = @length &- index &- 1
      @data.to_unsafe[rindex]
    end

    # set the length, without bounds checking.
    def size=(@length : UInt16) : UInt16
      length
    end

    def capacity : Int32
      Size.to_i32!
    end

    # append item to vector, without bounds checking.
    def push_unchecked(value : Limb) : Nil
      @data.to_unsafe[@length] = value
      @length &+= 1
    end

    # append item to vector, returning if item was added
    def try_push(value : Limb) : Bool
      if size < capacity
        push_unchecked(value)
        true
      else
        false
      end
    end

    # add items to the vector, from a span, without bounds checking
    def extend_unchecked(s : LimbSpan) : Nil
      ptr = @data.to_unsafe + @length
      s.to_unsafe.copy_to(ptr, s.size)
      @length &+= s.size
    end

    # try to add items to the vector, returning if items were added
    def try_extend(s : LimbSpan) : Bool
      if size &+ s.size <= capacity
        extend_unchecked(s)
        true
      else
        false
      end
    end

    # resize the vector, without bounds checking
    # if the new size is longer than the vector, assign value to each
    # appended item.
    def resize_unchecked(new_len : UInt16, value : Limb) : Nil
      if new_len > @length
        count = new_len &- @length
        first = @data.to_unsafe + @length
        count.times { |i| first[i] = value }
        @length = new_len
      else
        @length = new_len
      end
    end

    # try to resize the vector, returning if the vector was resized.
    def try_resize(new_len : UInt16, value : Limb) : Bool
      if new_len > capacity
        false
      else
        resize_unchecked(new_len, value)
        true
      end
    end

    # check if any limbs are non-zero after the given index.
    # this needs to be done in reverse order, since the index
    # is relative to the most significant limbs.
    def nonzero?(index : Int) : Bool
      while index < size
        if rindex(index) != 0
          return true
        end
        index &+= 1
      end
      false
    end

    # normalize the big integer, so most-significant zero limbs are removed.
    def normalize : Nil
      while @length > 0 && rindex(0) == 0
        @length &-= 1
      end
    end
  end

  # NOTE(crystal): returns also *truncated* by value (ditto below)
  def self.empty_hi64 : {UInt64, Bool}
    truncated = false
    {0_u64, truncated}
  end

  def self.uint64_hi64(r0 : UInt64) : {UInt64, Bool}
    truncated = false
    shl = r0.leading_zeros_count
    {r0.unsafe_shl(shl), truncated}
  end

  def self.uint64_hi64(r0 : UInt64, r1 : UInt64) : {UInt64, Bool}
    shl = r0.leading_zeros_count
    if shl == 0
      truncated = r1 != 0
      {r0, truncated}
    else
      shr = 64 &- shl
      truncated = r1.unsafe_shl(shl) != 0
      {r0.unsafe_shl(shl) | r1.unsafe_shr(shr), truncated}
    end
  end

  def self.uint32_hi64(r0 : UInt32) : {UInt64, Bool}
    uint64_hi64(r0.to_u64!)
  end

  def self.uint32_hi64(r0 : UInt32, r1 : UInt32) : {UInt64, Bool}
    x0 = r0.to_u64!
    x1 = r1.to_u64!
    uint64_hi64(x0.unsafe_shl(32) | x1)
  end

  def self.uint32_hi64(r0 : UInt32, r1 : UInt32, r2 : UInt32) : {UInt64, Bool}
    x0 = r0.to_u64!
    x1 = r1.to_u64!
    x2 = r2.to_u64!
    uint64_hi64(x0, x1.unsafe_shl(32) | x2)
  end

  # add two small integers, checking for overflow.
  # we want an efficient operation.
  # NOTE(crystal): returns also *overflow* by value
  def self.scalar_add(x : Limb, y : Limb) : {Limb, Bool}
    z = x &+ y
    overflow = z < x
    {z, overflow}
  end

  # multiply two small integers, getting both the high and low bits.
  # NOTE(crystal): passes *carry* in and out by value
  def self.scalar_mul(x : Limb, y : Limb, carry : Limb) : {Limb, Limb}
    {% if Limb == UInt64 %}
      z = x.to_u128! &* y.to_u128! &+ carry
      carry = z.unsafe_shr(LIMB_BITS).to_u64!
      {z.to_u64!, carry}
    {% else %}
      z = x.to_u64! &* y.to_u64! &+ carry
      carry = z.unsafe_shr(LIMB_BITS).to_u32!
      {z.to_u32!, carry}
    {% end %}
  end

  # add scalar value to bigint starting from offset.
  # used in grade school multiplication
  def self.small_add_from(vec : Stackvec(Size)*, y : Limb, start : Int) : Bool forall Size
    index = start
    carry = y

    while carry != 0 && index < vec.value.size
      x, overflow = scalar_add(vec.value.unsafe_fetch(index), carry)
      vec.value.unsafe_put(index, x)
      carry = Limb.new!(overflow ? 1 : 0)
      index &+= 1
    end
    if carry != 0
      fastfloat_try vec.value.try_push(carry)
    end
    true
  end

  # add scalar value to bigint.
  def self.small_add(vec : Stackvec(Size)*, y : Limb) : Bool forall Size
    small_add_from(vec, y, 0)
  end

  # multiply bigint by scalar value.
  def self.small_mul(vec : Stackvec(Size)*, y : Limb) : Bool forall Size
    carry = Limb.zero
    i = 0
    while i < vec.value.size
      xi = vec.value.unsafe_fetch(i)
      z, carry = scalar_mul(xi, y, carry)
      vec.value.unsafe_put(i, z)
      i &+= 1
    end
    if carry != 0
      fastfloat_try vec.value.try_push(carry)
    end
    true
  end

  # add bigint to bigint starting from index.
  # used in grade school multiplication
  def self.large_add_from(x : Stackvec(Size)*, y : LimbSpan, start : Int) : Bool forall Size
    # the effective x buffer is from `xstart..x.len()`, so exit early
    # if we can't get that current range.
    if x.value.size < start || y.size > x.value.size &- start
      fastfloat_try x.value.try_resize((y.size &+ start).to_u16!, 0)
    end

    carry = false
    index = 0
    while index < y.size
      xi = x.value.unsafe_fetch(index &+ start)
      yi = y.unsafe_fetch(index)
      c2 = false
      xi, c1 = scalar_add(xi, yi)
      if carry
        xi, c2 = scalar_add(xi, 1)
      end
      x.value.unsafe_put(index &+ start, xi)
      carry = c1 || c2
      index &+= 1
    end

    # handle overflow
    if carry
      fastfloat_try small_add_from(x, 1, y.size &+ start)
    end
    true
  end

  # add bigint to bigint.
  def self.large_add_from(x : Stackvec(Size)*, y : LimbSpan) : Bool forall Size
    large_add_from(x, y, 0)
  end

  # grade-school multiplication algorithm
  def self.long_mul(x : Stackvec(Size)*, y : LimbSpan) : Bool forall Size
    xs = x.value.to_slice
    z = Stackvec(Size).new(xs)
    zs = z.to_slice

    if y.size != 0
      y0 = y.unsafe_fetch(0)
      fastfloat_try small_mul(x, y0)
      (1...y.size).each do |index|
        yi = y.unsafe_fetch(index)
        zi = Stackvec(Size).new
        if yi != 0
          # re-use the same buffer throughout
          zi.size = 0
          fastfloat_try zi.try_extend(zs)
          fastfloat_try small_mul(pointerof(zi), yi)
          zis = zi.to_slice
          fastfloat_try large_add_from(x, zis, index)
        end
      end
    end

    x.value.normalize
    true
  end

  # grade-school multiplication algorithm
  def self.large_mul(x : Stackvec(Size)*, y : LimbSpan) : Bool forall Size
    if y.size == 1
      fastfloat_try small_mul(x, y.unsafe_fetch(0))
    else
      fastfloat_try long_mul(x, y)
    end
    true
  end

  module Pow5Tables
    LARGE_STEP = 135_u32

    SMALL_POWER_OF_5 = [
      1_u64,
      5_u64,
      25_u64,
      125_u64,
      625_u64,
      3125_u64,
      15625_u64,
      78125_u64,
      390625_u64,
      1953125_u64,
      9765625_u64,
      48828125_u64,
      244140625_u64,
      1220703125_u64,
      6103515625_u64,
      30517578125_u64,
      152587890625_u64,
      762939453125_u64,
      3814697265625_u64,
      19073486328125_u64,
      95367431640625_u64,
      476837158203125_u64,
      2384185791015625_u64,
      11920928955078125_u64,
      59604644775390625_u64,
      298023223876953125_u64,
      1490116119384765625_u64,
      7450580596923828125_u64,
    ]

    {% if Limb == UInt64 %}
      LARGE_POWER_OF_5 = Slice[
        1414648277510068013_u64, 9180637584431281687_u64, 4539964771860779200_u64,
        10482974169319127550_u64, 198276706040285095_u64,
      ]
    {% else %}
      LARGE_POWER_OF_5 = Slice[
        4279965485_u32, 329373468_u32, 4020270615_u32, 2137533757_u32, 4287402176_u32,
        1057042919_u32, 1071430142_u32, 2440757623_u32, 381945767_u32, 46164893_u32,
      ]
    {% end %}
  end

  # big integer type. implements a small subset of big integer
  # arithmetic, using simple algorithms since asymptotically
  # faster algorithms are slower for a small number of limbs.
  # all operations assume the big-integer is normalized.
  # NOTE(crystal): contrast with ::BigInt
  struct Bigint
    # storage of the limbs, in little-endian order.
    @vec = Stackvec(BIGINT_LIMBS).new

    def initialize
    end

    def initialize(value : UInt64)
      {% if Limb == UInt64 %}
        @vec.push_unchecked(value)
      {% else %}
        @vec.push_unchecked(value.to_u32!)
        @vec.push_unchecked(value.unsafe_shr(32).to_u32!)
      {% end %}
      @vec.normalize
    end

    # get the high 64 bits from the vector, and if bits were truncated.
    # this is to get the significant digits for the float.
    # NOTE(crystal): returns also *truncated* by value
    def hi64 : {UInt64, Bool}
      {% if Limb == UInt64 %}
        if @vec.empty?
          FastFloat.empty_hi64
        elsif @vec.size == 1
          FastFloat.uint64_hi64(@vec.rindex(0))
        else
          result, truncated = FastFloat.uint64_hi64(@vec.rindex(0), @vec.rindex(1))
          truncated ||= @vec.nonzero?(2)
          {result, truncated}
        end
      {% else %}
        if @vec.empty?
          FastFloat.empty_hi64
        elsif @vec.size == 1
          FastFloat.uint32_hi64(@vec.rindex(0))
        elsif @vec.size == 2
          FastFloat.uint32_hi64(@vec.rindex(0), @vec.rindex(1))
        else
          result, truncated = FastFloat.uint32_hi64(@vec.rindex(0), @vec.rindex(1), @vec.rindex(2))
          truncated ||= @vec.nonzero?(3)
          {result, truncated}
        end
      {% end %}
    end

    # compare two big integers, returning the large value.
    # assumes both are normalized. if the return value is
    # negative, other is larger, if the return value is
    # positive, this is larger, otherwise they are equal.
    # the limbs are stored in little-endian order, so we
    # must compare the limbs in ever order.
    def compare(other : Bigint*) : Int32
      if @vec.size > other.value.@vec.size
        1
      elsif @vec.size < other.value.@vec.size
        -1
      else
        index = @vec.size
        while index > 0
          xi = @vec.unsafe_fetch(index &- 1)
          yi = other.value.@vec.unsafe_fetch(index &- 1)
          if xi > yi
            return 1
          elsif xi < yi
            return -1
          end
          index &-= 1
        end
        0
      end
    end

    # shift left each limb n bits, carrying over to the new limb
    # returns true if we were able to shift all the digits.
    def shl_bits(n : Int) : Bool
      # Internally, for each item, we shift left by n, and add the previous
      # right shifted limb-bits.
      # For example, we transform (for u8) shifted left 2, to:
      #      b10100100 b01000010
      #      b10 b10010001 b00001000
      shl = n
      shr = LIMB_BITS &- n
      prev = Limb.zero
      index = 0
      while index < @vec.size
        xi = @vec.unsafe_fetch(index)
        @vec.unsafe_put(index, xi.unsafe_shl(shl) | prev.unsafe_shr(shr))
        prev = xi
        index &+= 1
      end

      carry = prev.unsafe_shr(shr)
      if carry != 0
        return @vec.try_push(carry)
      end
      true
    end

    # move the limbs left by `n` limbs.
    def shl_limbs(n : Int) : Bool
      if n &+ @vec.size > @vec.capacity
        false
      elsif !@vec.empty?
        # move limbs
        dst = @vec.to_unsafe + n
        src = @vec.to_unsafe
        src.move_to(dst, @vec.size)
        # fill in empty limbs
        first = @vec.to_unsafe
        n.times { |i| first[i] = 0 }
        @vec.size = (@vec.size &+ n).to_u16!
        true
      else
        true
      end
    end

    # move the limbs left by `n` bits.
    def shl(n : Int) : Bool
      rem = n.unsafe_mod(LIMB_BITS)
      div = n.unsafe_div(LIMB_BITS)
      if rem != 0
        FastFloat.fastfloat_try shl_bits(rem)
      end
      if div != 0
        FastFloat.fastfloat_try shl_limbs(div)
      end
      true
    end

    # get the number of leading zeros in the bigint.
    def ctlz : Int32
      if @vec.empty?
        0
      else
        @vec.rindex(0).leading_zeros_count.to_i32!
      end
    end

    # get the number of bits in the bigint.
    def bit_length : Int32
      lz = ctlz
      (LIMB_BITS &* @vec.size &- lz).to_i32!
    end

    def mul(y : Limb) : Bool
      FastFloat.small_mul(pointerof(@vec), y)
    end

    def add(y : Limb) : Bool
      FastFloat.small_add(pointerof(@vec), y)
    end

    # multiply as if by 2 raised to a power.
    def pow2(exp : UInt32) : Bool
      shl(exp)
    end

    # multiply as if by 5 raised to a power.
    def pow5(exp : UInt32) : Bool
      # multiply by a power of 5
      large = Pow5Tables::LARGE_POWER_OF_5
      while exp >= Pow5Tables::LARGE_STEP
        FastFloat.fastfloat_try FastFloat.large_mul(pointerof(@vec), large)
        exp &-= Pow5Tables::LARGE_STEP
      end
      small_step = {{ Limb == UInt64 ? 27_u32 : 13_u32 }}
      max_native = {{ Limb == UInt64 ? 7450580596923828125_u64 : 1220703125_u32 }}
      while exp >= small_step
        FastFloat.fastfloat_try FastFloat.small_mul(pointerof(@vec), max_native)
        exp &-= small_step
      end
      if exp != 0
        FastFloat.fastfloat_try FastFloat.small_mul(pointerof(@vec), Limb.new!(Pow5Tables::SMALL_POWER_OF_5.unsafe_fetch(exp)))
      end

      true
    end

    # multiply as if by 10 raised to a power.
    def pow10(exp : UInt32) : Bool
      FastFloat.fastfloat_try pow5(exp)
      pow2(exp)
    end
  end
end
