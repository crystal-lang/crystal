# The top-level number type.
struct Number
  include Comparable(Number)

  alias Primitive = Int::Primitive | Float::Primitive

  def self.zero : self
    new(0)
  end

  # Returns self.
  def +
    self
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
  macro [](*nums)
    Array({{@type}}).build({{nums.size}}) do |%buffer|
      {% for num, i in nums %}
        %buffer[{{i}}] = {{@type}}.new({{num}})
      {% end %}
      {{nums.size}}
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
  macro slice(*nums, read_only = false)
    %slice = Slice({{@type}}).new({{nums.size}}, read_only: {{read_only}})
    {% for num, i in nums %}
      %slice.to_unsafe[{{i}}] = {{@type}}.new({{num}})
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
  macro static_array(*nums)
    %array = uninitialized StaticArray({{@type}}, {{nums.size}})
    {% for num, i in nums %}
      %array.to_unsafe[{{i}}] = {{@type}}.new({{num}})
    {% end %}
    %array
  end

  # Invokes the given block with the sequence of numbers starting at `self`,
  # incremented by *by* on each call, and with an optional *to*.
  #
  # ```
  # 3.step(to: 10, by: 2) do |n|
  #   puts n
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 3
  # 5
  # 7
  # 9
  # ```
  def step(*, to = nil, by = 1)
    x = self + (by - by)

    if to
      if by > 0
        while x <= to
          yield x
          x += by
        end
      elsif by < 0
        while x >= to
          yield x
          x += by
        end
      end
    else
      while true
        yield x
        x += by
      end
    end

    self
  end

  def step(*, to = nil, by = 1)
    StepIterator.new(self + (by - by), to, by)
  end

  # Returns the absolute value of this number.
  #
  # ```
  # 123.abs  # => 123
  # -123.abs # => 123
  # ```
  def abs
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
  def sign
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
    {(self / number).floor, self % number}
  end

  # Implements the comparison operator.
  #
  # See also: `Object#<=>`.
  def <=>(other)
    self > other ? 1 : (self < other ? -1 : 0)
  end

  # Keeps *digits* significants digits of this number in the given *base*.
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

    x = self.to_f

    if x == 0
      return x
    end

    y = if base == 10
          10 ** ((Math.log10(self.abs) - digits + 1).floor)
        elsif base == 2
          2 ** ((Math.log2(self.abs) - digits + 1).floor)
        else
          base ** (((Math.log2(self.abs)) / (Math.log2(base)) - digits + 1).floor)
        end

    self.class.new((x / y).round * y)
  end

  # Rounds this number to a given precision in decimal *digits*.
  #
  # ```
  # -1763.116.round(2) # => -1763.12
  # ```
  def round(digits, base = 10)
    x = self.to_f
    if digits < 0
      y = base ** (-digits)
      self.class.new((x / y).round * y)
    else
      y = base ** digits
      self.class.new((x * y).round / y)
    end
  end

  # Clamps a value within *range*.
  #
  # ```
  # 5.clamp(10..100)   # => 10
  # 50.clamp(10..100)  # => 50
  # 500.clamp(10..100) # => 100
  # ```
  def clamp(range : Range)
    raise ArgumentError.new("Can't clamp an exclusive range") if range.exclusive?
    clamp range.begin, range.end
  end

  # Clamps a value between *min* and *max*.
  #
  # ```
  # 5.clamp(10, 100)   # => 10
  # 50.clamp(10, 100)  # => 50
  # 500.clamp(10, 100) # => 100
  # ```
  def clamp(min, max)
    return max if self > max
    return min if self < min
    self
  end

  # Returns `true` if value is equal to zero.
  #
  # ```
  # 0.zero? # => true
  # 5.zero? # => false
  # ```
  def zero? : Bool
    self == 0
  end

  private class StepIterator(T, L, B)
    include Iterator(T)

    @n : T
    @to : L
    @by : B
    @original : T

    def initialize(@n : T, @to : L, @by : B)
      @original = @n
    end

    def next
      if to = @to
        if @by > 0
          return stop if @n > to
        elsif @by < 0
          return stop if @n < to
        end

        value = @n
        @n += @by
        value
      else
        value = @n
        @n += @by
        value
      end
    end

    def rewind
      @n = @original
      self
    end
  end
end
