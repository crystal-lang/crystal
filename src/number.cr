# The top-level number type.
struct Number
  include Comparable(Number)
  include Steppable

  alias Primitive = Int::Primitive | Float::Primitive

  # Returns the value zero in the respective type.
  #
  # ```
  # Int32.zero   # => 0
  # Float64.zero # => 0.0
  # ```
  def self.zero : self
    new(0)
  end

  # Returns the additive identity of this type.
  #
  # For numerical types, it is the value `0` expressed in the respective type.
  #
  # ```
  # Int32.additive_identity   # => 0
  # Float64.additive_identity # => 0.0
  # ```
  def self.additive_identity : self
    zero
  end

  # Returns the multiplicative identity of this type.
  #
  # For numerical types, it is the value `1` expressed in the respective type.
  #
  # ```
  # Int32.multiplicative_identity   # => 1
  # Float64.multiplicative_identity # => 1.0
  # ```
  def self.multiplicative_identity : self
    new(1)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.number(self)
  end

  # Returns `self`.
  def +
    self
  end

  # Divides `self` by *other* using floored division.
  #
  # The result will be of the same type as `self`.
  def //(other)
    self.class.new((self / other).floor)
  end

  # :nodoc:
  macro expand_div(rhs_types, result_type)
    {% for rhs in rhs_types %}
      @[::AlwaysInline]
      def /(other : {{ rhs }}) : {{ result_type }}
        {{ result_type }}.new(self) / {{ result_type }}.new(other)
      end
    {% end %}
  end

  # Creates an `Array` of `self` with the given values, which will be casted
  # to this type with the `new` method (defined in each `Number` type).
  #
  # ```
  # floats = Float64[1, 2, 3, 4]
  # floats.class # => Array(Float64)
  #
  # ints = Int64[1, 2, 3]
  # ints.class # => Array(Int64)
  # ```
  #
  # This is similar to an array literal of the same item type:
  #
  # ```
  # Int64[1, 2, 3, 4]     # : Array(Int64)
  # [1, 2, 3, 4] of Int64 # : Array(Int64)
  # ```
  macro [](*nums)
    ::Array({{ @type }}).build({{ nums.size }}) do |%buffer|
      {% for num, i in nums %}
        %buffer[{{ i }}] = {{ @type }}.new({{ num }})
      {% end %}
      {{ nums.size }}
    end
  end

  # Creates a `Slice` of `self` with the given values, which will be casted
  # to this type with the `new` method (defined in each `Number` type).
  #
  # The slice is allocated on the heap.
  #
  # ```
  # floats = Float64.slice(1, 2, 3, 4)
  # floats.class # => Slice(Float64)
  #
  # ints = Int64.slice(1, 2, 3)
  # ints.class # => Slice(Int64)
  # ```
  #
  # This is a convenient alternative to `Slice.[]` for designating a
  # specific item type which also considers autocasting.
  #
  # ```
  # Int64.slice(1, 2, 3, 4)           # : Slice(Int64)
  # Slice[1_i64, 2_i64, 3_i64, 4_i64] # : Slice(Int64)
  # ```
  macro slice(*nums, read_only = false)
    %slice = ::Slice({{ @type }}).new({{ nums.size }}, read_only: {{ read_only }})
    {% for num, i in nums %}
      %slice.to_unsafe[{{ i }}] = {{ @type }}.new!({{ num }})
    {% end %}
    %slice
  end

  # Creates a `StaticArray` of `self` with the given values, which will be casted
  # to this type with the `new` method (defined in each `Number` type).
  #
  # ```
  # floats = Float64.static_array(1, 2, 3, 4)
  # floats.class # => StaticArray(Float64, 4)
  #
  # ints = Int64.static_array(1, 2, 3)
  # ints.class # => StaticArray(Int64, 3)
  # ```
  #
  # This is a convenvenient alternative to `StaticArray.[]` for designating a
  # specific item type which also considers autocasting.
  #
  # ```
  # Int64.static_array(1, 2, 3, 4)          # : StaticArray(Int64)
  # StaticArray[1_i64, 2_i64, 3_i64, 4_i64] # : StaticArray(Int64)
  # ```
  macro static_array(*nums)
    %array = uninitialized ::StaticArray({{ @type }}, {{ nums.size }})
    {% for num, i in nums %}
      %array.to_unsafe[{{ i }}] = {{ @type }}.new!({{ num }})
    {% end %}
    %array
  end

  # Performs a `#step` in the direction of the _limit_. For instance:
  #
  # ```
  # 10.step(to: 5).to_a # => [10, 9, 8, 7, 6, 5]
  # 5.step(to: 10).to_a # => [5, 6, 7, 8, 9, 10]
  # ```
  def step(*, to limit = nil, exclusive : Bool = false, &) : Nil
    if limit
      direction = limit <=> self
    end
    step = direction.try(&.sign) || 1

    step(to: limit, by: step, exclusive: exclusive) do |x|
      yield x
    end
  end

  # :ditto:
  def step(*, to limit = nil, exclusive : Bool = false)
    if limit
      direction = limit <=> self
    end
    step = direction.try(&.sign) || 1

    step(to: limit, by: step, exclusive: exclusive)
  end

  # Returns the absolute value of this number.
  #
  # ```
  # 123.abs  # => 123
  # -123.abs # => 123
  # ```
  def abs : self
    self < 0 ? -self : self
  end

  # Returns the square of `self` (`self * self`).
  #
  # ```
  # 4.abs2   # => 16
  # 1.5.abs2 # => 2.25
  # ```
  def abs2
    self * self
  end

  # Returns the sign of this number as an `Int32`.
  # * `-1` if this number is negative
  # * `0` if this number is zero
  # * `1` if this number is positive
  #
  # ```
  # 123.sign # => 1
  # 0.sign   # => 0
  # -42.sign # => -1
  # ```
  def sign : Int32
    self < 0 ? -1 : (self == 0 ? 0 : 1)
  end

  # Returns a `Tuple` of two elements containing the quotient
  # and modulus obtained by dividing `self` by *number*.
  #
  # ```
  # 11.divmod(3)  # => {3, 2}
  # 11.divmod(-3) # => {-4, -1}
  # ```
  def divmod(number)
    {(self // number).floor, self % number}
  end

  # The comparison operator.
  #
  # Returns:
  # - `-1` if `self` is less than *other*
  # - `0` if `self` is equal to *other*
  # - `1` if `self` is greater than *other*
  # - `nil` if `self` is `NaN` or *other* is `NaN`, because `NaN` values are not comparable
  def <=>(other) : Int32?
    # NaN can't be compared to other numbers
    return nil if self.is_a?(Float) && self.nan?
    return nil if other.is_a?(Float) && other.nan?

    self > other ? 1 : (self < other ? -1 : 0)
  end

  # Keeps *digits* significant digits of this number in the given *base*.
  #
  # ```
  # 1234.567.significant(1) # => 1000
  # 1234.567.significant(2) # => 1200
  # 1234.567.significant(3) # => 1230
  # 1234.567.significant(4) # => 1235
  # 1234.567.significant(5) # => 1234.6
  # 1234.567.significant(6) # => 1234.57
  # 1234.567.significant(7) # => 1234.567
  # 1234.567.significant(8) # => 1234.567
  #
  # 15.159.significant(1, base = 2) # => 16
  # ```
  def significant(digits, base = 10)
    if digits < 0
      raise ArgumentError.new "digits should be non-negative"
    end
    return self if zero?

    x = self.to_f

    if base == 10
      log = Math.log10(self.abs)
    elsif base == 2
      log = Math.log2(self.abs)
    else
      log = Math.log2(self.abs) / Math.log2(base)
    end

    exponent = (log - digits + 1).floor
    if exponent < 0
      y = base ** -exponent
      value = (x * y).round / y
    else
      y = base ** exponent
      value = (x / y).round * y
    end

    self.class.new(value)
  end

  # Rounds this number to a given precision.
  #
  # Rounds to the specified number of *digits* after the decimal place,
  # (or before if negative), in base *base*.
  #
  # The rounding *mode* controls the direction of the rounding. The default is
  # `RoundingMode::TIES_EVEN` which rounds to the nearest integer, with ties
  # (fractional value of `0.5`) being rounded to the even neighbor (Banker's rounding).
  #
  # ```
  # -1763.116.round(2) # => -1763.12
  # ```
  def round(digits : Number, base = 10, *, mode : RoundingMode = :ties_even)
    if digits < 0
      multiplier = base.to_f ** digits.abs
      shifted = self / multiplier
    else
      multiplier = base.to_f ** digits
      shifted = self * multiplier
    end

    rounded = shifted.round(mode)

    if digits < 0
      result = rounded * multiplier
    else
      result = rounded / multiplier
    end

    self.class.new result
  end

  # Specifies rounding behaviour for numerical operations capable of discarding
  # precision.
  enum RoundingMode
    # Rounds towards the nearest integer. If both neighboring integers are equidistant,
    # rounds towards the even neighbor (Banker's rounding).
    TIES_EVEN

    # Rounds towards the nearest integer. If both neighboring integers are equidistant,
    # rounds away from zero.
    TIES_AWAY

    # Rounds towards zero (truncate).
    TO_ZERO

    # Rounds towards positive infinity (ceil).
    TO_POSITIVE

    # Rounds towards negative infinity (floor).
    TO_NEGATIVE
  end

  # Rounds `self` to an integer value using rounding *mode*.
  #
  # The rounding *mode* controls the direction of the rounding. The default is
  # `RoundingMode::TIES_EVEN` which rounds to the nearest integer, with ties
  # (fractional value of `0.5`) being rounded to the even neighbor (Banker's rounding).
  def round(mode : RoundingMode = :ties_even) : self
    case mode
    in .to_zero?
      trunc
    in .to_positive?
      ceil
    in .to_negative?
      floor
    in .ties_away?
      round_away
    in .ties_even?
      round_even
    end
  end

  # Returns `true` if `self` is an integer.
  #
  # Non-integer types may return `true` as long as `self` denotes a finite value
  # without any fractional parts.
  #
  # ```
  # 1.integer?       # => true
  # 1.0.integer?     # => true
  # 1.2.integer?     # => false
  # (1 / 0).integer? # => false
  # (0 / 0).integer? # => false
  # ```
  def integer? : Bool
    self % 1 == 0
  end

  # Returns `true` if `self` is equal to zero.
  #
  # ```
  # 0.zero? # => true
  # 5.zero? # => false
  # ```
  def zero? : Bool
    self == 0
  end

  # Returns `true` if `self` is greater than zero.
  #
  # ```
  # -1.positive? # => false
  # 0.positive?  # => false
  # 1.positive?  # => true
  # ```
  def positive? : Bool
    self > 0
  end

  # Returns `true` if `self` is less than zero.
  #
  # ```
  # -1.negative? # => true
  # 0.negative?  # => false
  # 1.negative?  # => false
  # ```
  def negative? : Bool
    self < 0
  end
end
