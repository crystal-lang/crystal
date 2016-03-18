# An Iterator allows processing sequences lazily, as opposed to `Enumerable` which processes
# sequences eagerly and produces an `Array` in most of its methods.
#
# As an example, let's compute the first three numbers in the range `1..10_000_000` that are even,
# multiplied by three. One way to do this is:
#
# ```
# (1..10_000_000).select(&.even?).map { |x| x * 3 }.first(3) # => [6, 12, 18]
# ```
#
# The above works, but creates many intermediate arrays: one for the *select* call,
# one for the *map* call and one for the *take* call. A more efficient way is to invoke
# `Range#each` without a block, which gives us an Iterator so we can process the operations
# lazily:
#
# ```
# (1..10_000_000).each.select(&.even?).map { |x| x * 3 }.first(3) # => #< Iterator(T)::First...
# ```
#
# Iterator redefines many of `Enumerable`'s method in a lazy way, returning iterators
# instead of arrays.
#
# At the end of the call chain we get back a new iterator: we need to consume it, either
# using `each` or `Enumerable#to_a`:
#
# ```
# (1..10_000_000).each.select(&.even?).map { |x| x * 3 }.first(3).to_a # => [6, 12, 18]
# ```
#
# To implement an Iterator you need to define a `next` method that must return the next
# element in the sequence or `Iterator::Stop::INSTANCE`, which signals the end of the sequence
# (you can invoke `stop` inside an iterator as a shortcut).
#
# Additionally, an `Iterator` can implement `rewind`, which must rewind the iterator to
# its initial state. This is needed to implement the `cycle` method.
#
# For example, this is an iterator that returns a sequence of N zeros:
#
# ```
# class Zeros
#   include Iterator(Int32)
#
#   def initialize(@size)
#     @produced = 0
#   end
#
#   def next
#     if @produced < @size
#       @produced += 1
#       0
#     else
#       stop
#     end
#   end
#
#   def rewind
#     @produced = 0
#     self
#   end
# end
#
# zeros = Zeros.new(5)
# zeros.to_a # => [0, 0, 0, 0, 0]
#
# zeros.rewind
# zeros.first(3).to_a # => [0, 0, 0]
# ```
#
# The standard library provides iterators for many classes, like `Array`, `Hash`, `Range`, `String` and `IO`.
# Usually to get an iterator you invoke a method that would usually yield elements to a block,
# but without passing a block: `Array#each`, `Array#each_index`, `Hash#each`, `String#each_char`,
# `IO#each_line`, etc.
module Iterator(T)
  include Enumerable(T)

  # The class that signals that there are no more elements in an iterator.
  class Stop
    INSTANCE = new
  end

  # IteratorWrapper eliminates some boilerplate when defining an Iterator that wraps another iterator.
  #
  # To use it, include this module in your iterator and make sure that the wrapped
  # iterator is stored in the `@iterator` instance variable.
  module IteratorWrapper
    # Rewinds the wrapped iterator and returns self.
    def rewind
      @iterator.rewind
      self
    end

    # Invokes `next` on the wrapped iterator and returns `stop` if
    # the given value was a Stop. Otherwise, returns the value.
    macro wrapped_next
      %value = @iterator.next
      return stop if %value.is_a?(Stop)
      %value
    end
  end

  # Shortcut for `Iterator::Stop::INSTANCE`, to signal that there are no more elements in an iterator.
  def stop
    Iterator.stop
  end

  # ditto
  def self.stop
    Stop::INSTANCE
  end

  def self.of(element : T)
    Singleton(T).new(element)
  end

  # :nodoc:
  struct Singleton(T)
    include Iterator(T)

    @element : T

    def initialize(@element : T)
    end

    def next
      @element
    end

    def rewind
      self
    end
  end

  def self.of(&block : -> T)
    SingletonProc(T).new(block)
  end

  # :nodoc:
  struct SingletonProc(T)
    include Iterator(T)

    @proc : -> T

    def initialize(@proc : -> T)
    end

    def next
      @proc.call
    end
  end

  # Returns the next element in this iterator, or `Iterator::Stop::INSTANCE` if there
  # are no more elements.
  abstract def next

  # Rewinds the iterator to its original state.
  abstract def rewind

  # Returns an iterator that returns elements from the original iterator until
  # it is exhausted and then returns the elements of the second iterator.
  #
  #     iter = (1..2).each.chain(('a'..'b').each)
  #     iter.next # => 1
  #     iter.next # => 2
  #     iter.next # => 'a'
  #     iter.next # => 'b'
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def chain(other : Iterator(U))
    Chain(typeof(self), typeof(other), T, U).new(self, other)
  end

  # :nodoc:
  class Chain(I1, I2, T1, T2)
    include Iterator(T1 | T2)

    @iterator1 : I1
    @iterator2 : I2
    @iterator1_consumed : Bool

    def initialize(@iterator1, @iterator2)
      @iterator1_consumed = false
    end

    def next
      if @iterator1_consumed
        @iterator2.next
      else
        value = @iterator1.next
        if value.is_a?(Stop)
          @iterator1_consumed = true
          value = @iterator2.next
        end
        value
      end
    end

    def rewind
      @iterator1.rewind
      @iterator2.rewind
      @iterator1_consumed = false
    end
  end

  # Return an iterator that applies the given function to the element and then
  # returns it unless it is nil. If the returned value would be nil it instead
  # returns the next non nil value.
  #
  #     iter = [1, nil, 2, nil].each.compact_map {|e| e.try &.*(2)}
  #     iter.next # => 2
  #     iter.next # => 4
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def compact_map(&func : T -> U)
    CompactMap(typeof(self), T, typeof(func.call(first).not_nil!)).new(self, func)
  end

  # :nodoc:
  struct CompactMap(I, T, U)
    include Iterator(U)
    include IteratorWrapper

    @iterator : I
    @func : T -> U?

    def initialize(@iterator : Iterator(T), @func)
    end

    def next
      while true
        value = wrapped_next
        mapped_value = @func.call(value)

        return mapped_value unless mapped_value.is_a?(Nil)
      end
    end
  end

  # Returns an iterator that returns consecutive chunks of the size *n*.
  #
  #     iter = (1..5).each.cons(3)
  #     iter.next # => [1, 2, 3]
  #     iter.next # => [2, 3, 4]
  #     iter.next # => [3, 4, 5]
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def cons(n : Int)
    raise ArgumentError.new "invalid cons size: #{n}" if n <= 0
    Cons(typeof(self), T, typeof(n)).new(self, n)
  end

  # :nodoc:
  struct Cons(I, T, N)
    include Iterator(Array(T))
    include IteratorWrapper

    @iterator : I
    @n : N
    @values : Array(T)

    def initialize(@iterator : Iterator(T), @n : N)
      @values = Array(T).new(@n)
    end

    def next
      loop do
        elem = wrapped_next
        @values << elem
        @values.shift if @values.size > @n
        break if @values.size == @n
      end
      @values.dup
    end

    def rewind
      @values.clear
      super
    end
  end

  # Returns an iterator that repeatedly returns the elements of the original
  # iterator forever starting back at the beginning when the end was reached.
  #
  #     iter = ["a", "b", "c"].each.cycle
  #     iter.next # => "a"
  #     iter.next # => "b"
  #     iter.next # => "c"
  #     iter.next # => "a"
  #     iter.next # => "b"
  #     iter.next # => "c"
  #     iter.next # => "a"
  #     # and so an and so on
  def cycle
    Cycle(typeof(self), T).new(self)
  end

  # :nodoc:
  struct Cycle(I, T)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I

    def initialize(@iterator : Iterator(T))
    end

    def next
      value = @iterator.next
      if value.is_a?(Stop)
        @iterator.rewind
        @iterator.next
      else
        value
      end
    end
  end

  # Returns an iterator that repeatedly returns the elements of the original
  # iterator starting back at the beginning when the end was reached,
  # but only n times.
  #
  #     iter = ["a", "b", "c"].each.cycle(2)
  #     iter.next # => "a"
  #     iter.next # => "b"
  #     iter.next # => "c"
  #     iter.next # => "a"
  #     iter.next # => "b"
  #     iter.next # => "c"
  #     iter.next # => Iterator::Stop::INSTANCE
  def cycle(n : Int)
    CycleN(typeof(self), T, typeof(n)).new(self, n)
  end

  # :nodoc:
  class CycleN(I, T, N)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @n : N
    @count : Int32

    def initialize(@iterator : Iterator(T), @n : N)
      @count = 0
    end

    def next
      return stop if @count >= @n
      value = @iterator.next
      if value.is_a?(Stop)
        @count += 1
        return stop if @count >= @n

        @iterator.rewind
        @iterator.next
      else
        value
      end
    end

    def rewind
      @count = 0
      super
    end
  end

  def each
    self
  end

  # Calls the given block once for each element, passing that element
  # as a parameter.
  #
  #     iter = [ "a", "b", "c" ].each
  #     iter.each {|x| print x, " " } # Prints "a b c"
  #
  def each
    while true
      value = self.next
      break if value.is_a?(Stop)
      yield value
    end
  end

  # Returns an iterator that then returns slices of n elements of the initial
  # iterator.
  #
  #     iter = (1..9).each.each_slice(3)
  #     iter.next # => [1, 2, 3]
  #     iter.next # => [4, 5, 6]
  #     iter.next # => [7, 8, 9]
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def each_slice(n)
    slice(n)
  end

  # Returns an iterator that flattens nested iterators into a single iterator
  # whose type is the union of the simple types of all of the nested iterators
  # (and their nested iterators, and so on).
  #
  #     iter = [(1..2).each, ('a'..'b').each].each.flatten
  #     iter.next # => 1
  #     iter.next # => 2
  #     iter.next # => 'a'
  #     iter.next # => 'b'
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def flatten
    Flatten(self, typeof(Flatten.element_type(self))).new(self)
  end

  # :nodoc:
  class Flatten(I, T1)
    include Iterator(T1)

    @iterator : I
    @top : Bool
    @to_rewind : Array(Proc(Nil))

    # @generator : I

    def initialize(@iterator)
      @generator = @iterator
      @top = true
      @to_rewind = [] of Proc(Nil)
    end

    def next
      value = @generator.next
      if value.is_a?(Stop)
        if @top
          return stop
        else
          @generator = @iterator
          @top = true
          return self.next
        end
      end

      flatten value
    end

    def make_rewinder(iter)
      ->{
        iter.rewind
        # Return nil to disguise the individual iterator types
        nil
      }
    end

    def rewind
      @iterator.rewind
      @generator = @iterator
      @top = true
      @to_rewind.each &.call
      @to_rewind.clear
    end

    def flatten(element)
      case element
      when Iterator
        flat = element.flatten
        @generator = flat
        @to_rewind << make_rewinder flat
        @top = false
        self.next
      when Iterable
        flatten element.each
      else
        element
      end
    end

    def self.element_type(element)
      case element
      when Stop
        raise ""
      when Iterator
        element_type(element.next)
      when Iterable
        element_type(element.each)
      else
        element
      end
    end
  end

  # Returns an iterator that chunks the iterator's elements in arrays of *size*
  # filling up the remaining elements if no element remains with nil or a given
  # optional parameter.
  #
  #     iter = (1..3).each.in_groups_of(2)
  #     iter.next # => [1, 2]
  #     iter.next # => [3, nil]
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  #     iter = (1..3).each.in_groups_of(2, 'z')
  #     iter.next # => [1, 2]
  #     iter.next # => [3, 'z']
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def in_groups_of(size : Int, filled_up_with = nil)
    raise ArgumentError.new("size must be positive") if size <= 0
    InGroupsOf(typeof(self), T, typeof(size), typeof(filled_up_with)).new(self, size, filled_up_with)
  end

  # :nodoc:
  struct InGroupsOf(I, T, N, U)
    include Iterator(Array(T | U))
    include IteratorWrapper

    @iterator : I
    @size : N
    @filled_up_with : U

    def initialize(@iterator : Iterator(T), @size : N, @filled_up_with : U)
    end

    def next
      value = wrapped_next
      array = Array(T | U).new(@size)
      array << value
      (@size - 1).times do
        new_value = @iterator.next
        new_value = @filled_up_with if new_value.is_a?(Stop)
        array << new_value
      end
      array
    end
  end

  # Returns an iterator that applies the given block to the next element and
  # returns the result.
  #
  #
  #     iter = [1, 2, 3].each.map &.*(2)
  #     iter.next # => 2
  #     iter.next # => 4
  #     iter.next # => 6
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def map(&func : T -> U)
    Map(typeof(self), T, U).new(self, func)
  end

  # :nodoc:
  struct Map(I, T, U)
    include Iterator(U)
    include IteratorWrapper

    @iterator : I
    @func : T -> U

    def initialize(@iterator : Iterator(T), @func : T -> U)
    end

    def next
      value = wrapped_next
      @func.call(value)
    end
  end

  # Returns an iterator that only returns elements for which the the passed in
  # block returns a falsey value.
  #
  #     iter = [1, 2, 3].each.reject &.odd?
  #     iter.next # => 2
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def reject(&func : T -> U)
    Reject(typeof(self), T, U).new(self, func)
  end

  # :nodoc:
  struct Reject(I, T, B)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @func : T -> B

    def initialize(@iterator : Iterator(T), @func : T -> B)
    end

    def next
      while true
        value = wrapped_next
        unless @func.call(value)
          return value
        end
      end
    end
  end

  # Returns an iterator that only returns elements for which the the passed
  # in block returns a truthy value.
  #
  #     iter = [1, 2, 3].each.select &.odd?
  #     iter.next # => 1
  #     iter.next # => 3
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def select(&func : T -> U)
    Select(typeof(self), T, U).new(self, func)
  end

  # :nodoc:
  struct Select(I, T, B)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @func : T -> B

    def initialize(@iterator : Iterator(T), @func : T -> B)
    end

    def next
      while true
        value = wrapped_next
        if @func.call(value)
          return value
        end
      end
    end
  end

  # Returns an iterator that skips the first *n* elements and only returns
  # the elements after that.
  #
  #     iter = (1..3).each.skip(2)
  #     iter.next # -> 3
  #     iter.next # -> Iterator::Stop::INSTANCE
  #
  def skip(n : Int)
    raise ArgumentError.new "Attempted to skip negative size: #{n}" if n < 0
    Skip(typeof(self), T, typeof(n)).new(self, n)
  end

  # :nodoc:
  class Skip(I, T, N)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @n : N
    @original : N

    def initialize(@iterator : Iterator(T), @n : Int)
      @original = @n
    end

    def next
      while @n > 0
        @n -= 1
        wrapped_next
      end
      @iterator.next
    end

    def rewind
      @n = @original
      super
    end
  end

  # Returns an iterator that only starts to return elements once the given block
  # has returned falsey value for one element.
  #
  #     iter = [1, 2, 3, 4, 0].each.skip_while { |i| i < 3}
  #     iter.next # => 3
  #     iter.next # => 4
  #     iter.next # => 0
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def skip_while(&func : T -> U)
    SkipWhile(typeof(self), T, U).new(self, func)
  end

  # :nodoc:
  class SkipWhile(I, T, U)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @func : T -> U
    @returned_false : Bool

    def initialize(@iterator : Iterator(T), @func : T -> U)
      @returned_false = false
    end

    def next
      while true
        value = wrapped_next
        return value if @returned_false == true
        unless @func.call(value)
          @returned_false = true
          return value
        end
      end
    end

    def rewind
      @returned_false = false
      super
    end
  end

  # Returns an iterator that returns slices of n elements of the initial
  # iterator.
  #
  #     iter = (1..9).each.slice(3)
  #     iter.next # => [1, 2, 3]
  #     iter.next # => [4, 5, 6]
  #     iter.next # => [7, 8, 9]
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def slice(n : Int)
    raise ArgumentError.new "invalid slice size: #{n}" if n <= 0
    Slice(typeof(self), T, typeof(n)).new(self, n)
  end

  # :nodoc:
  struct Slice(I, T, N)
    include Iterator(Array(T))
    include IteratorWrapper

    @iterator : I
    @n : N

    def initialize(@iterator : Iterator(T), @n)
    end

    def next
      values = Array(T).new(@n)
      @n.times do
        value = @iterator.next
        break if value.is_a?(Stop)

        values << value
      end

      if values.empty?
        stop
      else
        values
      end
    end
  end

  # Returns an iterator that only returns every *n*th element, starting with the
  # first.
  #
  #     iter = (1..6).each.step(2)
  #     iter.next # => 1
  #     iter.next # => 3
  #     iter.next # => 5
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def step(n : Int)
    Step(self, T, typeof(n)).new(self, n)
  end

  # :nodoc:
  struct Step(I, T, N)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @n : N

    def initialize(@iterator : I, @n : N)
      raise ArgumentError.new("n must be greater or equal 1") if @n < 1
    end

    def next
      value = @iterator.next
      return stop if value.is_a?(Stop)

      (@n - 1).times do
        @iterator.next
      end

      value
    end
  end

  # Returns an iterator that only returns the first n elements of the
  # initial iterator.
  #
  #     iter = ["a", "b", "c"].each.first 2
  #     iter.next # => "a"
  #     iter.next # => "b"
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def first(n : Int)
    raise ArgumentError.new "Attempted to take negative size: #{n}" if n < 0
    First(typeof(self), T, typeof(n)).new(self, n)
  end

  # :nodoc:
  class First(I, T, N)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @n : N
    @original : N

    def initialize(@iterator : Iterator(T), @n : Int)
      @original = @n
    end

    def next
      if @n > 0
        @n -= 1
        wrapped_next
      else
        stop
      end
    end

    def rewind
      @n = @original
      super
    end
  end

  # Returns an iterator that returns elements while the given block returns a
  # truthy value.
  #
  #     iter = (1..5).each.take_while {|i| i <3 }
  #     iter.next # => 1
  #     iter.next # => 2
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def take_while(&func : T -> U)
    TakeWhile(typeof(self), T, U).new(self, func)
  end

  # :nodoc:
  class TakeWhile(I, T, U)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @func : T -> U
    @returned_false : Bool

    def initialize(@iterator : Iterator(T), @func : T -> U)
      @returned_false = false
    end

    def next
      return stop if @returned_false == true
      value = wrapped_next
      if @func.call(value)
        value
      else
        @returned_false = true
        stop
      end
    end

    def rewind
      @returned_false = false
      super
    end
  end

  # Returns an iterator that calls the given block with the next element of the
  # iterator when calling `next`, still returning the original element.
  #
  #     a = 0
  #     iter = (1..3).each.tap { |x| a += x}
  #     iter.next # => 1
  #     a         # => 1
  #     iter.next # => 2
  #     a         # => 3
  #     iter.next # => 3
  #     a         # => 6
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def tap(&block : T ->)
    Tap(typeof(self), T).new(self, block)
  end

  # :nodoc:
  struct Tap(I, T)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @proc : T ->

    def initialize(@iterator, @proc)
    end

    def next
      value = wrapped_next
      @proc.call(value)
      value
    end
  end

  # Returns an iterator that only returns unique values of the original
  # iterator.
  #
  #     iter = [1, 2, 1].each.uniq
  #     iter.next # => 1
  #     iter.next # => 2
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def uniq
    uniq &.itself
  end

  # Returns an iterator that only returns unique values of the original
  # iterator. The provided block is applied to the elements to determine the
  # value to be checked for uniqueness.
  #
  #     iter = [["a", "a"], ["b", "a"], ["a", "c"]].uniq &.first
  #     iter.next # => ["a", "a"]
  #     iter.next # => ["b", "a"]
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def uniq(&func : T -> U)
    Uniq(typeof(self), T, U).new(self, func)
  end

  # :nodoc:
  struct Uniq(I, T, U)
    include Iterator(T)
    include IteratorWrapper

    @iterator : I
    @func : T -> U
    @hash : Hash(T, Bool)

    def initialize(@iterator : Iterator(T), @func : T -> U)
      @hash = {} of T => Bool
    end

    def next
      while true
        value = wrapped_next
        transformed = @func.call value

        unless @hash[transformed]?
          @hash[transformed] = true
          return value
        end
      end
    end

    def rewind
      @hash.clear
      super
    end
  end

  # Returns an iterator that returns a tuple of the element and its index.
  #
  #     iter = (1..3).each.with_index
  #     iter.next # => {1, 0}
  #     iter.next # => {2, 1}
  #     iter.next # => {3, 2}
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def with_index(offset : Int = 0)
    WithIndex(typeof(self), T, typeof(offset)).new(self, offset)
  end

  # :nodoc:
  class WithIndex(I, T, O)
    include Iterator({T, Int32})
    include IteratorWrapper

    @iterator : I
    @offset : O
    @index : O

    def initialize(@iterator : Iterator(T), @offset, @index = offset)
    end

    def next
      v = wrapped_next
      value = {v, @index}
      @index += 1
      value
    end

    def rewind
      @index = @offset
      super
    end
  end

  # Returns an iterator that returns a tuple of the element and a given object.
  #
  #     iter = (1..3).each.with_object("a")
  #     iter.next # => {1, "a"}
  #     iter.next # => {2, "a"}
  #     iter.next # => {3, "a"}
  #     iter.next # => Iterator::Stop::INSTANCE
  #
  def with_object(obj)
    WithObject(typeof(self), T, typeof(obj)).new(self, obj)
  end

  # :nodoc:
  struct WithObject(I, T, O)
    include Iterator({T, O})
    include IteratorWrapper

    @iterator : I
    @object : O

    def initialize(@iterator : Iterator(T), @object : O)
    end

    def next
      v = wrapped_next
      {v, @object}
    end
  end

  # Returns an iterator that returns the elements of this iterator and the given
  # one pairwise as tuples.
  #
  #    iter1 = [4, 5, 6].each
  #    iter2 = [7, 8, 9].each
  #    iter = iter1.zip(iter2)
  #    iter.next # => {4, 7}
  #    iter.next # => {5, 8}
  #    iter.next # => {6, 9}
  #    iter.next # => Iterator::Stop::INSTANCE
  #
  def zip(other : Iterator(U))
    Zip(typeof(self), typeof(other), T, U).new(self, other)
  end

  # :nodoc:
  struct Zip(I1, I2, T1, T2)
    include Iterator({T1, T2})

    @iterator1 : I1
    @iterator2 : I2

    def initialize(@iterator1, @iterator2)
    end

    def next
      v1 = @iterator1.next
      return stop if v1.is_a?(Stop)

      v2 = @iterator2.next
      return stop if v2.is_a?(Stop)

      {v1, v2}
    end

    def rewind
      @iterator1.rewind
      @iterator2.rewind
      self
    end
  end
end
