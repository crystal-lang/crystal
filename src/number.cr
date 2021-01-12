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
  # If *exclusive* is `true`, *limit* is excluded from the iteration.
  #
  # ```
  # ary = [] of Int32
  # 1.step(to: 4, by: 2) do |x|
  #   ary << x
  # end
  # ary                                        # => [1, 3]
  # 1.step(to: 4, by: 2).to_a                  # => [1, 3]
  # 1.step(to: 4, by: 1).to_a                  # => [1, 2, 3, 4]
  # 1.step(to: 4, by: 1, exclusive: true).to_a # => [1, 2, 3]
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
  def step(*, to limit = nil, by step, exclusive : Bool = false, &) : Nil
    # type of current should be the result of adding `step`:
    current = self + (step - step)

    if limit == current
      # Only yield current if it's also the limit.
      # Step size doesn't matter in this case: `1.step(to: 1, by: 0)` yields `1`
      yield current unless exclusive
      return
    end

    raise ArgumentError.new("Zero step size") if step.zero?

    direction = step.sign

    if limit
      # if limit and step size have different directions, we can't iterate
      return unless (limit <=> current).try(&.sign) == direction

      yield current

      while true
        # only proceed if difference to limit is at least as big as step size to
        # avoid potential overflow errors.
        sign = ((limit - current) <=> step).try(&.sign)
        break unless sign == direction || (sign == 0 && !exclusive)

        current += step
        yield current
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
  def step(*, to limit = nil, by step, exclusive : Bool = false)
    raise ArgumentError.new("Zero step size") if step.zero? && limit != self

    StepIterator.new(self + (step - step), limit, step, exclusive: exclusive)
  end

  # :ditto:
  def step(*, to limit = nil, exclusive : Bool = false)
    if limit
      direction = limit <=> self
    end
    step = direction.try(&.sign) || 1

    step(to: limit, by: step, exclusive: exclusive)
  end

  class StepIterator(T, L, B)
    include Iterator(T)

    @current : T
    @limit : L
    @step : B
    @at_start = true
    @reached_end = false

    def initialize(@current : T, @limit : L, @step : B, @exclusive : Bool)
    end

    def next
      return stop if @reached_end
      limit = @limit

      if @at_start
        @at_start = false

        if limit
          sign = (limit <=> @current).try(&.sign)
          @reached_end = sign == 0

          # iteration is empty if limit and step are in different directions
          if (!@reached_end && sign != @step.sign) || (@reached_end && @exclusive)
            @reached_end = true
            return stop
          end
        end

        @current
      elsif limit
        # compare distance to current with step size
        case (limit - @current <=> @step).try(&.sign)
        when @step.sign
          # distance is more than step size, so iteration proceeds
          @current += @step
        when 0
          # distance is exactly step size, so we're at the end
          @reached_end = true
          if @exclusive
            stop
          else
            @current + @step
          end
        else
          # we've either overshot the limit or the comparison failed, so we can't
          # continue
          @reached_end = true

          stop
        end
      else
        @current += @step
      end
    end

    # Overrides `Enumerable#sum` to use more performant implementation on integer
    # ranges.
    def sum(initial)
      return super if @reached_end

      current = @current
      limit = @limit
      step = @step

      if current.is_a?(Int) && limit.is_a?(Int) && step.is_a?(Int)
        limit -= 1 if @exclusive
        n = (limit - current) // step + 1
        if n >= 0
          limit = current + (n - 1) * step
          initial + n * (current + limit) // 2
        else
          initial
        end
      else
        super
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
