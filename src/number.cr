# The top-level number type.
struct Number
  include Comparable(Number)

  def self.zero
    cast(0)
  end

  # Returns self.
  def +
    self
  end

  # Creates an Array of self with the given values, which will be casted
  # to this type with the `cast` method (defined in each Number type).
  #
  # ```
  # floats = Float64[1, 2, 3, 4]
  # floats.class                 #=> Array(Float64)
  #
  # ints = Int64[1, 2, 3]
  # ints.class                   #=> Array(Int64)
  # ```
  def self.[](*nums)
    Array(self).build(nums.length) do |buffer|
      nums.each_with_index do |num, i|
        buffer[i] = cast(num)
      end
      nums.length
    end
  end

  # Invokes the given block with the sequence of numbers starting at `self`,
  # incremented by `by` on each call, and with an optional `limit`.
  #
  # ```
  # 3.step(by: 2, limit: 10) do |n|
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
  def step(limit = nil, by = 1)
    x = self + (by - by)

    if limit
      if by > 0
        while x <= limit
          yield x
          x += by
        end
      elsif by < 0
        while x >= limit
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

  def step(limit = nil, by = 1)
    StepIterator.new(self + (by - by), limit, by)
  end

  # Returns the absolute value of this number.
  #
  # ```
  # 123.abs  #=> 123
  # -123.abs #=> 123
  # ```
  def abs
    self < 0 ? -self : self
  end

  # Returns the square of self (`self * self`).
  #
  # ```
  # 4.abs2   #=> 16
  # 1.5.abs2 #=> 2.25
  # ```
  def abs2
    self * self
  end

  # Returns the sign of this number as an Int32.
  # * -1 if this number is negative
  # * 0 if this number is zero
  # * 1 if this number is positive
  #
  # ```
  # 123.sign #=> 1
  # 0.sign   #=> 0
  # -42.sign #=> -1
  # ```
  def sign
    self < 0 ? -1 : (self == 0 ? 0 : 1)
  end

  # Return a tuple of two elements containing the quotient
  # and modulus obtained by dividing self by `number`.
  #
  # ```
  # 11.divmod(3)  #=> {3, 2}
  # 11.divmod(-3) #=> {-3, 2}
  # ```
  def divmod(number)
    {self / number, self % number}
  end

  # Implements the comparison operator.
  #
  # See `Object#<=>`
  def <=>(other)
    self > other ? 1 : (self < other ? -1 : 0)
  end

  # Keeps `digits` significants digits of this number in the given `base`.
  #
  # ```
  # 1234.567.significant(1)         #=> 1000
  # 1234.567.significant(2)         #=> 1200
  # 1234.567.significant(3)         #=> 1230
  # 1234.567.significant(4)         #=> 1235
  # 1234.567.significant(5)         #=> 1234.6
  # 1234.567.significant(6)         #=> 1234.57
  # 1234.567.significant(7)         #=> 1234.567
  # 1234.567.significant(8)         #=> 1234.567
  #
  # 15.159.significant(1, base = 2) #=> 16
  # ```
  def significant(digits, base = 10)
    if digits < 0
      raise DomainError.new "digits should be non-negative"
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

    self.class.cast((x / y).round * y)
  end

  # Rounds this number to a given precision in decimal digits.
  #
  # ```
  # -1763.116.round(2) #=> -1763.12
  # ```
  def round(digits, base = 10)
    x = self.to_f
    y = base ** digits
    self.class.cast((x * y).round / y)
  end

  class StepIterator(T, L, B)
    include Iterator(T)

    def initialize(@n : T, @limit : L, @by : B)
      @original = @n
    end

    def next
      if limit = @limit
        if @by > 0
          return stop if @n > limit
        elsif @by < 0
          return stop if @n < limit
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
