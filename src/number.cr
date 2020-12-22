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

  # Divides `self` by *other* using floored division.
  #
  # The result will be of the same type as `self`.
  def //(other)
    self.class.new((self / other).floor)
  end

  # :nodoc:
  macro expand_div(rhs_types, result_type)
    {% for rhs in rhs_types %}
      @[AlwaysInline]
      def /(other : {{rhs}}) : {{result_type}}
        {{result_type}}.new(self) / {{result_type}}.new(other)
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
      %slice.to_unsafe[{{i}}] = {{@type}}.new!({{num}})
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
      %array.to_unsafe[{{i}}] = {{@type}}.new!({{num}})
    {% end %}
    %array
  end

  # Iterates from `self` to *limit* incrementing by the amount of *step* on each
  # iteration.
  #
  # ```
  # ary = [] of Int32
  # 1.step(to: 4, by: 2) do |x|
  #   ary << x
  # end
  # ary                       # => [1, 3]
  # 1.step(to: 4, by: 2).to_a # => [1, 3]
  # ```
  #
  # The type of each iterated element is `typeof(self + step)`.
  #
  # If *to* is `nil`, iteration is open ended.
  #
  # The starting point (`self`) is always iterated as first element, with two
  # exceptions:
  # * if `self` and *to* don't compare (i.e. `(self <=> to).nil?`). Example:
  #   `1.0.step(Float::NAN)`
  # * if the direction of *to* differs from the direction of `by`. Example:
  #   `1.step(to: 2, by: -1)`
  #
  # In those cases the iteration is empty.
  def step(*, to limit = nil, by step)
    # type of current should be the result of adding `step`:
    current = self + (step - step)

    if limit == current
      yield current
      return
    elsif step.zero?
      raise ArgumentError.new("Zero step size")
    end

    direction = step.sign

    if limit
      return unless (limit <=> current).try(&.sign) == direction

      yield current

      while ((limit - current) <=> step) == direction
        current += step
        yield current
      end

      if (limit - current <=> step) == 0
        yield current + step
      end
    else
      while true
        yield current
        current += step
      end
    end

    self
  end

  # :ditto:
  def step(*, to limit = nil, &)
    if limit
      direction = limit <=> self
    end
    step = self.class.new(direction.try(&.sign) || 1)

    step(to: limit, by: step) do |x|
      yield x
    end
  end

  # :ditto:
  def step(*, to limit = nil, by step)
    raise ArgumentError.new("Zero step size") if step.zero? && limit != self

    StepIterator.new(self + (step - step), limit, step)
  end

  # :ditto:
  def step(*, to limit = nil)
    if limit
      direction = limit <=> self
    end
    step = self.class.new(direction.try(&.sign) || 1)

    step(to: limit, by: step)
  end

  class StepIterator(T, L, B)
    include Iterator(T)

    @current : T
    @limit : L
    @step : B
    @started = false
    @reached_end = false

    def initialize(@current : T, @limit : L, @step : B)
    end

    def next
      return stop if @reached_end
      limit = @limit

      if !@started
        if limit
          unless (limit <=> @current).try(&.sign).in?(0, @step.sign)
            @reached_end = true
            return stop
          end
        end

        @started = true
        @reached_end = @current == limit
        @current
      elsif limit
        if (limit - @current <=> @step) == @step.sign
          @current += @step
        else
          @reached_end = true

          if (limit - @current <=> @step) == 0
            @current + @step
          else
            stop
          end
        end
      else
        @current += @step
      end
    end
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
    {(self // number).floor, self % number}
  end

  # The comparison operator.
  #
  # Returns:
  # - `-1` if `self` is less than *other*
  # - `0` if `self` is equal to *other*
  # - `-1` if `self` is greater than *other*
  # - `nil` if self is `NaN` or *other* is `NaN`, because `NaN` values are not comparable
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
  def round(digits = 0, base = 10)
    x = self.to_f
    if digits < 0
      y = base.to_f ** digits.abs
      self.class.new((x / y).round * y)
    else
      y = base.to_f ** digits
      self.class.new((x * y).round / y)
    end
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
end
