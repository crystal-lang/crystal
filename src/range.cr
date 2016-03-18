# A Range represents an interval: a set of values with a beginning and an end.
#
# Ranges may be constructed using the usual `new` method or with literals:
#
# ```
# x..y  # an inclusive range, in mathematics: [x, y]
# x...y # an exclusive range, in mathematics: [x, y)
# ```
#
# An easy way to remember which one is inclusive and which one is exclusive it
# to think of the extra dot as if it pushes *y* further away, thus leaving it outside of the range.
#
# Ranges typically involve integers, but can be created using arbitrary objects as long as they define `succ` (or `pred`
# for `reverse_each`), to get the next element in the range, and `<` and `==`, to know when the range reached the end:
#
# ```
# # Represents a string of 'x's.
# struct Xs
#   include Comparable(Xs)
#
#   getter size
#
#   def initialize(@size)
#   end
#
#   def succ
#     Xs.new(@size + 1)
#   end
#
#   def <=>(other)
#     @size <=> other.size
#   end
#
#   def inspect(io)
#     @size.times { io << 'x' }
#   end
#
#   def to_s(io)
#     io << @size << ' '
#     inspect(io)
#   end
# end
# ```
#
# An example of using `Xs` to construct a range:
#
# ```
# r = Xs.new(3)..Xs.new(6) # => xxx..xxxxxx
# r.to_a                   # => [xxx, xxxx, xxxxx, xxxxxx]
# r.includes?(Xs.new(5))   # => true
# ```
struct Range(B, E)
  include Enumerable(B)
  include Iterable

  # Returns the object that defines the beginning of this range.
  #
  # ```
  # (1..10).begin  # => 1
  # (1...10).begin # => 1
  # ```
  getter begin : B

  # Returns the object that defines the end of the range.
  #
  # ```
  # (1..10).end  # => 10
  # (1...10).end # => 10
  # ```
  getter end : E

  # Returns `true` if the range is exclusive.
  # Returns `false` otherwise (default).
  getter? exclusive : Bool

  # Constructs a range using the given beginning and end.
  #
  # ```
  # Range.new(1, 10)                  # => 1..10
  # Range.new(1, 10, exclusive: true) # => 1...10
  # ```
  def initialize(@begin : B, @end : E, @exclusive : Bool = false)
  end

  # Returns an `Iterator` that cycles over the values of this range.
  #
  # ```
  # (1..3).cycle.first(5).to_a # => [1, 2, 3, 1, 3]
  # ```
  def cycle
    each.cycle
  end

  # Iterates over the elements of this range, passing each in turn to the block.
  #
  # ```
  # (10..15).each { |n| print n, ' ' }
  # # prints: 10 11 12 13 14 15
  # ```
  def each
    current = @begin
    while current < @end
      yield current
      current = current.succ
    end
    yield current if !@exclusive && current == @end
    self
  end

  # Returns an `Iterator` over the elements of this range.
  #
  # ```
  # (1..3).each.skip(1).to_a # => [2, 3]
  # ```
  def each
    ItemIterator.new(self)
  end

  # Iterates over the elements of this range in reverse order, passing each in turn to the block.
  #
  # ```
  # (10...15).reverse_each { |n| print n, ' ' }
  # # prints: 14 13 12 11 10
  # ```
  def reverse_each
    yield @end if !@exclusive && !(@end < @begin)
    current = @end
    while @begin < current
      current = current.pred
      yield current
    end
    self
  end

  # Iterates over this range, passing each nth element to the block.
  #
  # ```
  # range = Xs.new(1)..Xs.new(10)
  # range.step(2) { |x| puts x }
  # puts
  # range.step(3) { |x| puts x }
  # ```
  #
  # Produces:
  #
  # ```text
  # 1 x
  # 3 xxx
  # 5 xxxxx
  # 7 xxxxxxx
  # 9 xxxxxxxxx
  #
  # 1 x
  # 4 xxxx
  # 7 xxxxxxx
  # 10 xxxxxxxxxx
  # ```
  #
  # See `Range`'s overview for the definition of `Xs`.
  def step(n = 1)
    current = @begin
    while current < @end
      yield current
      n.times { current = current.succ }
    end
    yield current if current == @end && !@exclusive
    self
  end

  # Returns an `Iterator` that returns each nth element in this range.
  #
  # ```
  # (1..10).step(3).skip(1).to_a # => [4, 7, 10]
  # ```
  def step(n : Int = 1)
    StepIterator(self, B, typeof(n)).new(self, n)
  end

  # Returns true if this range excludes the *end* element.
  #
  # ```
  # (1..10).excludes_end?  # => false
  # (1...10).excludes_end? # => true
  # ```
  def excludes_end?
    @exclusive
  end

  # Returns true if this range includes the given *value*.
  #
  # ```
  # (1..10).includes?(4)  # => true
  # (1..10).includes?(10) # => true
  # (1..10).includes?(11) # => false
  #
  # (1...10).includes?(9)  # => true
  # (1...10).includes?(10) # => false
  # ```
  def includes?(value)
    if @exclusive
      @begin <= value < @end
    else
      @begin <= value <= @end
    end
  end

  # Same as `includes?`
  def covers?(value)
    includes?(value)
  end

  # Same as `includes?`, useful for the `case` expression.
  #
  # ```
  # case 79
  # when 1..50   then puts "low"
  # when 51..75  then puts "medium"
  # when 76..100 then puts "high"
  # end
  # ```
  #
  # Produces:
  #
  # ```text
  # high
  # ```
  #
  # See `Object#===`.
  def ===(value)
    includes?(value)
  end

  # :nodoc:
  def to_s(io : IO)
    @begin.inspect(io)
    io << (@exclusive ? "..." : "..")
    @end.inspect(io)
  end

  # :nodoc:
  def inspect(io)
    to_s(io)
  end

  # If self is a `Int` range, it provides O(1) implementation,
  # otherwise it is same as `Enumerable#sum`.
  def sum(initial)
    b = self.begin
    e = self.end

    if b.is_a?(Int) && e.is_a?(Int)
      e -= 1 if @exclusive
      n = e - b + 1
      if n >= 0
        initial + n * (b + e) / 2
      else
        initial
      end
    else
      super
    end
  end

  # :nodoc:
  class ItemIterator(B, E)
    include Iterator(B)

    @range : Range(B, E)
    @current : B
    @reached_end : Bool

    def initialize(@range : Range(B, E), @current = range.begin, @reached_end = false)
    end

    def next
      return stop if @reached_end

      if @current < @range.end
        value = @current
        @current = @current.succ
        value
      else
        @reached_end = true

        if !@range.excludes_end? && @current == @range.end
          @current
        else
          stop
        end
      end
    end

    def rewind
      @current = @range.begin
      @reached_end = false
      self
    end
  end

  # :nodoc:
  class StepIterator(R, B, N)
    include Iterator(B)

    @range : R
    @step : N
    @current : B
    @reached_end : Bool

    def initialize(@range, @step, @current = range.begin, @reached_end = false)
    end

    def next
      return stop if @reached_end

      if @current < @range.end
        value = @current
        @step.times { @current = @current.succ }
        value
      else
        @reached_end = true

        if !@range.excludes_end? && @current == @range.end
          @current
        else
          stop
        end
      end
    end

    def rewind
      @current = @range.begin
      @reached_end = false
      self
    end

    def sum(initial)
      super if @reached_end

      b = @current
      e = @range.end
      d = @step

      if b.is_a?(Int) && e.is_a?(Int) && d.is_a?(Int)
        e -= 1 if @range.excludes_end?
        n = (e - b) / d + 1
        if n >= 0
          e = b + (n - 1) * d
          initial + n * (b + e) / 2
        else
          initial
        end
      else
        super
      end
    end
  end
end
