# A `Range` represents an interval: a set of values with a beginning and an end.
#
# Ranges may be constructed using the usual `new` method or with literals:
#
# ```
# x..y  # an inclusive range, in mathematics: [x, y]
# x...y # an exclusive range, in mathematics: [x, y)
# (x..) # an endless range, in mathematics: >= x
# ..y   # a beginless inclusive range, in mathematics: <= y
# ...y  # a beginless exclusive range, in mathematics: < y
# ```
#
# An easy way to remember which one is inclusive and which one is exclusive it
# to think of the extra dot as if it pushes *y* further away, thus leaving it outside of the range.
#
# Ranges typically involve integers, but can be created using arbitrary objects
# as long as they define `succ` (or `pred` for `reverse_each`), to get the
# next element in the range, and `<` and `==`, to know when the range reached the end:
#
# ```
# # Represents a string of 'x's.
# struct Xs
#   include Comparable(Xs)
#
#   getter size
#
#   def initialize(@size : Int32)
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
# r = Xs.new(3)..Xs.new(6)
# r.to_s                 # => "xxx..xxxxxx"
# r.to_a                 # => [Xs.new(3), Xs.new(4), Xs.new(5), Xs.new(6)]
# r.includes?(Xs.new(5)) # => true
# ```
struct Range(B, E)
  include Enumerable(B)
  include Iterable(B)

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

  # Constructs a `Range` using the given beginning and end.
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
  # (1..3).cycle.first(5).to_a # => [1, 2, 3, 1, 2]
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
  def each : Nil
    {% if B == Nil %}
      {% raise "Can't each beginless range" %}
    {% end %}

    current = @begin
    if current.nil?
      raise ArgumentError.new("Can't each beginless range")
    end

    # TODO: This typeof and the macro interpolations are a workaround until #9324 is fixed.
    typeof(yield current)

    {% if E == Nil %}
      while true
        {{ "yield current".id }}
        current = current.succ
      end
    {% else %}
      end_value = @end
      while end_value.nil? || current < end_value
        {{ "yield current".id }}
        current = current.succ
      end
      {{ "yield current".id }} if !@exclusive && current == end_value
    {% end %}
  end

  # Returns an `Iterator` over the elements of this range.
  #
  # ```
  # (1..3).each.skip(1).to_a # => [2, 3]
  # ```
  def each
    {% if B == Nil %}
      {% raise "Can't each beginless range" %}
    {% end %}

    if @begin.nil?
      raise ArgumentError.new("Can't each beginless range")
    end

    ItemIterator.new(self)
  end

  # Iterates over the elements of this range in reverse order,
  # passing each in turn to the block.
  #
  # ```
  # (10...15).reverse_each { |n| print n, ' ' }
  # # prints: 14 13 12 11 10
  # ```
  def reverse_each : Nil
    {% if E == Nil %}
      {% raise "Can't reverse_each endless range" %}
    {% end %}

    end_value = @end
    if end_value.nil?
      raise ArgumentError.new("Can't reverse_each endless range")
    end

    begin_value = @begin

    yield end_value if !@exclusive && (begin_value.nil? || !(end_value < begin_value))
    current = end_value

    # TODO: The macro interpolations are a workaround until #9324 is fixed.

    {% if B == Nil %}
      while true
        current = current.pred
        {{ "yield current".id }}
      end
    {% else %}
      while begin_value.nil? || begin_value < current
        current = current.pred
        {{ "yield current".id }}
      end
    {% end %}
  end

  # Returns a reverse `Iterator` over the elements of this range.
  #
  # ```
  # (1..3).reverse_each.skip(1).to_a # => [2, 1]
  # ```
  def reverse_each
    {% if E == Nil %}
      {% raise "Can't reverse_each endless range" %}
    {% end %}

    if @end.nil?
      raise ArgumentError.new("Can't reverse_each endless range")
    end

    ReverseIterator.new(self)
  end

  # Iterates from `begin` to `end` incrementing by the amount of *step* on each
  # iteration.
  #
  # ```
  # ary = [] of Int32
  # (1..4).step(by: 2) do |x|
  #   ary << x
  # end
  # ary                                      # => [1, 3]
  # (1..4).step(by: 2).to_a                  # => [1, 3]
  # (1..4).step(by: 1).to_a                  # => [1, 2, 3, 4]
  # (1..4).step(by: 1, exclusive: true).to_a # => [1, 2, 3]
  # ```
  #
  # The implementation is based on `B#step` method if available. The interface
  # is defined at `Number#step`.
  # Otherwise `#succ` method is expected to be defined on `begin` and its
  # successors and iteration is based on calling `#succ` sequentially
  # (*step* times per iteration).
  #
  # Raises `ArgumentError` if `begin` is `nil`.
  def step(by = 1, &) : Nil
    current = @begin
    if current.nil?
      raise ArgumentError.new("Can't step beginless range")
    end

    if current.responds_to?(:step)
      current.step(to: @end, by: by, exclusive: @exclusive) do |x|
        yield x
      end
    else
      end_value = @end
      while end_value.nil? || current < end_value
        yield current
        by.times do
          current = current.succ
          return if end_value && current > end_value
        rescue exc : OverflowError
          if current == end_value
            return
          else
            raise exc
          end
        end
      end
      yield current if !@exclusive && current == @end
    end
  end

  # :ditto:
  def step(by = 1) : Iterator
    start = @begin
    if start.nil?
      raise ArgumentError.new("Can't step beginless range")
    end

    if start.responds_to?(:step)
      start.step(to: @end, by: by, exclusive: @exclusive)
    else
      StepIterator(self, B, typeof(by)).new(self, by)
    end
  end

  # Returns `true` if this range excludes the *end* element.
  #
  # ```
  # (1..10).excludes_end?  # => false
  # (1...10).excludes_end? # => true
  # ```
  def excludes_end?
    @exclusive
  end

  # Returns `true` if this range includes the given *value*.
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
    begin_value = @begin
    end_value = @end

    # begin passes
    (begin_value.nil? || value >= begin_value) &&
      # end passes
      (end_value.nil? ||
        (@exclusive ? value < end_value : value <= end_value))
  end

  # Same as `includes?`.
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
  # See also: `Object#===`.
  def ===(value)
    includes?(value)
  end

  # :nodoc:
  def to_s(io : IO) : Nil
    @begin.try &.inspect(io)
    io << (@exclusive ? "..." : "..")
    @end.try &.inspect(io)
  end

  # :nodoc:
  def inspect(io : IO) : Nil
    to_s(io)
  end

  # Optimized version of `Enumerable#sum` that runs in O(1) time when `self` is
  # an `Int` range.
  def sum(initial)
    b = self.begin
    e = self.end

    if b.is_a?(Int) && e.is_a?(Int)
      e -= 1 if @exclusive
      n = e - b + 1
      if n >= 0
        initial + n * (b + e) // 2
      else
        initial
      end
    else
      super
    end
  end

  # Optimized version of `Enumerable#sample` that runs in O(1) time when `self`
  # is an `Int` or `Float` range. In these cases, this range is considered to be
  # a distribution of numeric values rather than a collection of elements, and
  # the method simply calls `random.rand(self)`.
  #
  # Raises `ArgumentError` if `self` is an open range.
  def sample(random = Random::DEFAULT)
    {% if B == Nil || E == Nil %}
      {% raise "Can't sample an open range" %}
    {% end %}

    {% if B < Int && E < Int %}
      random.rand(self)
    {% elsif B < Float && E < Float %}
      random.rand(self)
    {% elsif B.nilable? || E.nilable? %}
      b = self.begin
      e = self.end

      if b.nil? || e.nil?
        raise ArgumentError.new("Can't sample an open range")
      end

      Range.new(b, e, @exclusive).sample(random)
    {% else %}
      super
    {% end %}
  end

  # :nodoc:
  def sample(n : Int, random = Random::DEFAULT)
    {% if B == Nil || E == Nil %}
      {% raise "Can't sample an open range" %}
    {% end %}

    if self.begin.nil? || self.end.nil?
      raise ArgumentError.new("Can't sample an open range")
    end

    return super unless n == 1

    if empty?
      [] of B
    else
      [sample(random)]
    end
  end

  # Returns a new `Range` with `begin` and `end` cloned.
  def clone
    Range.new(@begin.clone, @end.clone, @exclusive)
  end

  # :nodoc:
  def map(&block : B -> U) forall U
    b = self.begin
    e = self.end

    # Optimized implementation for int range
    if b.is_a?(Int) && e.is_a?(Int)
      e -= 1 if @exclusive
      n = e - b + 1
      n = 0 if n < 0
      Array(U).new(n) { |i| yield b + i }
    else
      super { |i| yield i }
    end
  end

  # :nodoc:
  def size
    {% if B == Nil || E == Nil %}
      {% raise "Can't calculate size of an open range" %}
    {% end %}

    b = self.begin
    e = self.end

    # Optimized implementation for int range
    if b.is_a?(Int) && e.is_a?(Int)
      e -= 1 if @exclusive
      n = e - b + 1
      n < 0 ? 0 : n
    else
      if b.nil? || e.nil?
        raise ArgumentError.new("Can't calculate size of an open range")
      end
      super
    end
  end

  private class ItemIterator(B, E)
    include Iterator(B)

    @range : Range(B, E)
    @current : B
    @reached_end : Bool

    def initialize(@range : Range(B, E), @current = range.begin, @reached_end = false)
    end

    def next
      return stop if @reached_end

      end_value = @range.end

      if end_value.nil? || @current < end_value
        value = @current
        @current = @current.succ
        value
      else
        @reached_end = true

        if !@range.excludes_end? && @current == end_value
          @current
        else
          stop
        end
      end
    end
  end

  private class ReverseIterator(B, E)
    include Iterator(E)

    @range : Range(B, E)
    @current : E

    def initialize(@range : Range(B, E))
      if range.excludes_end?
        @current = range.end.not_nil!
      else
        @current = range.end.not_nil!.succ
      end
    end

    def next
      begin_value = @range.begin

      return stop if !begin_value.nil? && @current <= begin_value
      return @current = @current.pred
    end
  end

  private class StepIterator(R, B, N)
    include Iterator(B)

    @range : R
    @step : N
    @current : B
    @reached_end : Bool
    @at_start = true

    def initialize(@range, @step, @current = range.begin, @reached_end = false)
    end

    def next
      return stop if @reached_end

      end_value = @range.end

      if @at_start
        @at_start = false

        if end_value
          if @current > end_value || (@current == end_value && @range.exclusive?)
            @reached_end = true
            return stop
          end
        end

        return @current
      end

      if end_value.nil? || @current < end_value
        @step.times do
          if end_value && @current >= end_value
            @reached_end = true
            return stop
          end

          @current = @current.succ
        end

        if @current == end_value && @range.exclusive?
          @reached_end = true
          stop
        else
          @current
        end
      else
        @reached_end = true
        stop
      end
    end

    def sum(initial)
      return super if @reached_end

      b = @current
      e = @range.end
      d = @step

      if b.is_a?(Int) && e.is_a?(Int) && d.is_a?(Int)
        e -= 1 if @range.excludes_end?
        n = (e - b) // d + 1
        if n >= 0
          e = b + (n - 1) * d
          initial + n * (b + e) // 2
        else
          initial
        end
      else
        super
      end
    end
  end
end

require "./range/*"
