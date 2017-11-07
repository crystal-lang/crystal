# A `BigDecimal` represents arbitrary precision decimals.
#
# It is internally represented by a pair of `BigInt` and `UInt64`: value and scale.
# Value contains the actual value, and scale tells the decimal point place.
# e.g. value=1234, scale=2 => 12.34
#
# The general idea and some of the arithmetic algorithms were adapted from
# the MIT/APACHE -licensed https://github.com/akubera/bigdecimal-rs

class InvalidBigDecimalException < Exception
  def initialize(big_decimal_str : String, reason : String)
    super("Invalid BigDecimal: #{big_decimal_str} (#{reason})")
  end
end

struct BigDecimal < Number
  ZERO                       = BigInt.new(0)
  TEN                        = BigInt.new(10)
  DEFAULT_MAX_DIV_ITERATIONS = 100_u64

  include Comparable(Number)
  include Comparable(BigDecimal)

  getter value : BigInt
  getter scale : UInt64

  # Creates a new `BigDecimal` from a `String`.
  #
  # Allows only valid number strings with an optional negative sign.
  def initialize(str : String)
    raise InvalidBigDecimalException.new(str, "Zero size") if str.bytesize == 0

    # Check str's validity and find index of .
    decimal_index = nil
    str.each_char_with_index do |char, index|
      case char
      when '-'
        if index != 0
          raise InvalidBigDecimalException.new(str, "Unexpected '-' character")
        end
      when '.'
        if decimal_index
          raise InvalidBigDecimalException.new(str, "Unexpected '.' character")
        end

        decimal_index = index
      when '0'..'9'
        # Pass
      else
        raise InvalidBigDecimalException.new(str, "Unexpected #{char.inspect} character")
      end
    end

    if decimal_index
      value_str = String.build do |builder|
        # We know this is ASCII, so we can slice by index
        builder.write(str.to_slice[0, decimal_index])
        builder.write(str.to_slice[decimal_index + 1, str.bytesize - decimal_index - 1])
      end

      @value = value_str.to_big_i
      @scale = (str.bytesize - decimal_index - 1).to_u64
    else
      @value = str.to_big_i
      @scale = 0_u64
    end
  end

  # Creates an new `BigDecimal` from `Int`.
  def initialize(num : Int)
    initialize(num.to_big_i, 0)
  end

  # Creating a `BigDecimal` from `Float`.
  #
  # NOTE: Floats are fundamentally less precise than BigDecimals, which makes initialization from them risky.
  def initialize(num : Float)
    initialize num.to_s
  end

  # Creates a new `BigDecimal` from `BigInt`/`UInt64`, which matches the internal representation.
  def initialize(@value : BigInt, @scale : UInt64)
  end

  def initialize(value : Int, scale : Int)
    initialize(value.to_big_i, scale.to_u64)
  end

  def initialize(value : BigInt)
    initialize(value, 0u64)
  end

  def initialize
    initialize(0)
  end

  # Returns *num*. Useful for generic code that does `T.new(...)` with `T`
  # being a `Number`.
  def self.new(num : BigDecimal)
    num
  end

  def +(other : BigDecimal) : BigDecimal
    if @scale > other.scale
      scaled = other.scale_to(self)
      BigDecimal.new(@value + scaled.value, @scale)
    elsif @scale < other.scale
      scaled = scale_to(other)
      BigDecimal.new(scaled.value + other.value, other.scale)
    else
      BigDecimal.new(@value + other.value, @scale)
    end
  end

  def -(other : BigDecimal) : BigDecimal
    if @scale > other.scale
      scaled = other.scale_to(self)
      BigDecimal.new(@value - scaled.value, @scale)
    elsif @scale < other.scale
      scaled = scale_to(other)
      BigDecimal.new(scaled.value - other.value, other.scale)
    else
      BigDecimal.new(@value - other.value, @scale)
    end
  end

  def *(other : BigDecimal) : BigDecimal
    BigDecimal.new(@value * other.value, @scale + other.scale)
  end

  def /(other : BigDecimal) : BigDecimal
    div other
  end

  # Divides self with another `BigDecimal`, with a optionally configurable *max_div_iterations*, which
  # defines a maximum number of iterations in case the division is not exact.
  #
  # ```
  # BigDecimal(1).div(BigDecimal(2))    # => BigDecimal(@value=5, @scale=2)
  # BigDecimal(1).div(BigDecimal(3), 5) # => BigDecimal(@value=33333, @scale=5)
  # ```
  def div(other : BigDecimal, max_div_iterations = DEFAULT_MAX_DIV_ITERATIONS) : BigDecimal
    check_division_by_zero other

    scale = @scale - other.scale
    numerator, denominator = @value, other.@value

    quotient, remainder = numerator.divmod(denominator)
    if remainder == ZERO
      return BigDecimal.new(normalize_quotient(other, quotient), scale)
    end

    remainder = remainder * TEN

    i = 0
    while remainder != ZERO && i < max_div_iterations
      inner_quotient, inner_remainder = remainder.divmod(denominator)
      quotient = quotient * TEN + inner_quotient
      remainder = inner_remainder * TEN
      i += 1
    end

    BigDecimal.new(normalize_quotient(other, quotient), scale + i)
  end

  def <=>(other : BigDecimal) : Int32
    if @scale > other.scale
      @value <=> other.scale_to(self).value
    elsif @scale < other.scale
      scale_to(other).value <=> other.value
    else
      @value <=> other.value
    end
  end

  def <=>(other : Int)
    self <=> BigDecimal.new(other)
  end

  def ==(other : BigDecimal) : Bool
    if @scale > other.scale
      scaled = other.value * power_ten_to(@scale - other.scale)
      @value == scaled
    elsif @scale < other.scale
      scaled = @value * power_ten_to(other.scale - @scale)
      scaled == other.value
    else
      @value == other.value
    end
  end

  # Scales a `BigDecimal` to another `BigDecimal`, so they can be
  # computed easier.
  def scale_to(new_scale : BigDecimal) : BigDecimal
    new_scale = new_scale.scale

    if @value == 0
      BigDecimal.new(0.to_big_i, new_scale)
    elsif @scale > new_scale
      scale_diff = @scale - new_scale.to_big_i
      BigDecimal.new(@value / power_ten_to(scale_diff), new_scale)
    elsif @scale < new_scale
      scale_diff = new_scale - @scale.to_big_i
      BigDecimal.new(@value * power_ten_to(scale_diff), new_scale)
    else
      self
    end
  end

  def to_s(io : IO)
    factor_powers_of_ten
    s = @value.to_s

    if @scale == 0
      io << s
      return
    end

    if @scale >= s.size && @value >= 0
      io << "0."
      (@scale - s.size).times do
        io << '0'
      end
      io << s
    elsif @scale >= s.size && @value < 0
      io << "-0.0"
      (@scale - s.size).times do
        io << '0'
      end
      io << s[1..-1]
    else
      offset = s.size - @scale
      io << s[0...offset] << '.' << s[offset..-1]
    end
  end

  def to_big_d
    self
  end

  # Converts to integer. Truncates anything on the right side of the decimal point.
  def to_i
    if @value >= 0
      (@value / TEN ** @scale).to_i
    else
      -(@value.abs / TEN ** @scale).to_i
    end
  end

  # Converts to unsigned integer. Truncates anything on the right side of the decimal point,
  # converting negative to positive.
  def to_u
    (@value.abs / TEN ** @scale).to_u
  end

  def to_f
    to_s.to_f
  end

  def clone
    self
  end

  def hash(hasher)
    hasher.string(self.to_s)
  end

  # Returns the *quotient* as absolutely negative if self and other have different signs,
  # otherwise returns the *quotient*.
  def normalize_quotient(other : BigDecimal, quotient : BigInt) : BigInt
    if (@value < 0 && other.value > 0) || (other.value < 0 && @value > 0)
      -quotient.abs
    else
      quotient
    end
  end

  private def check_division_by_zero(bd : BigDecimal)
    raise DivisionByZero.new if bd.value == 0
  end

  private def power_ten_to(x : Int) : Int
    TEN ** x
  end

  # Factors out any extra powers of ten in the internal representation.
  # For instance, value=100 scale=2 => value=1 scale=0
  private def factor_powers_of_ten
    while @scale > 0
      quotient, remainder = value.divmod(TEN)
      break if remainder != 0

      @value = quotient
      @scale = @scale - 1
    end
  end
end

struct Int
  include Comparable(BigDecimal)

  # Convert `Int` to `BigDecimal`.
  def to_big_d
    BigDecimal.new(self)
  end

  def <=>(other : BigDecimal)
    self <=> other.value
  end
end

class String
  include Comparable(BigDecimal)

  # Convert `String` to `BigDecimal`.
  def to_big_d
    BigDecimal.new(self)
  end
end

struct Float
  # NOTE: Floats are fundamentally less precise than BigDecimals, which makes initialization from them risky.
  def to_big_d
    BigDecimal.new(self)
  end
end
