# An Iterator allows processing sequences lazily, as opposed to `Enumerable` which processes
# sequences eagerly and produces an `Array` in most of its methods.
#
# As an example, let's compute the first three numbers in the range `1..10_000_000` that are even,
# multiplied by three. One way to do this is:
#
# ```
# (1..10_000_000).select(&.even?).map { |x| x * 3 }.take(3) #=> [6, 12, 18]
# ```
#
# The above works, but creates many intermediate arrays: one for the *select* call,
# one for the *map* call and one for the *take* call. A more efficient way is to invoke
# `Range#each` without a block, which gives us an Iterator so we can process the operations
# lazily:
#
# ```
# (1..10_000_000).each.select(&.even?).map { |x| x * 3 }.take(3) #=> #< Iterator(T)::Take...
# ```
#
# Iterator redefines many of `Enumerable`'s method in a lazy way, returning iterators
# instead of arrays.
#
# At the end of the call chain we get back a new iterator: we need to consume it, either
# using `each` or `Enumerable#to_a`:
#
# ```
# (1..10_000_000).each.select(&.even?).map { |x| x * 3 }.take(3).to_a #=> [6, 12, 18]
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
#   def initialize(@length)
#     @produced = 0
#   end
#
#   def next
#     if @produced < @length
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
# zeros.to_a            #=> [0, 0, 0, 0, 0]
#
# zeros.rewind
# zeros.take(3).to_a    #=> [0, 0, 0]
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

  def self.of(&block : -> T)
    SingletonProc(T).new(block)
  end

  # Returns the next element in this iterator, or `Iterator::Stop::INSTANCE` if there
  # are no more elements.
  abstract def next

  # Rewinds the iterator to its original state.
  abstract def rewind

  def chain(other : Iterator(U))
    Chain(typeof(self), typeof(other), T, U).new(self, other)
  end

  def compact_map(&func : T -> U)
    CompactMap(typeof(self), T, typeof(func.call(first).not_nil!)).new(self, func)
  end

  def cons(n)
    raise ArgumentError.new "invalid cons size: #{n}" if n <= 0
    Cons(typeof(self), T).new(self, n)
  end

  def cycle
    Cycle(typeof(self), T).new(self)
  end

  def cycle(n : Int)
    CycleN(typeof(self), T, typeof(n)).new(self, n)
  end

  def each
    self
  end

  def each
    while true
      value = self.next
      break if value.is_a?(Stop)
      yield value
    end
  end

  def each_slice(n)
    slice(n)
  end

  def in_groups_of(size : Int, filled_up_with = nil)
    raise ArgumentError.new("size must be positive") if size <= 0
    InGroupsOf(typeof(self), T, typeof(size), typeof(filled_up_with)).new(self, size, filled_up_with)
  end

  def map(&func : T -> U)
    Map(typeof(self), T, U).new(self, func)
  end

  def reject(&func : T -> U)
    Reject(typeof(self), T, U).new(self, func)
  end

  def select(&func : T -> U)
    Select(typeof(self), T, U).new(self, func)
  end

  def skip(n)
    raise ArgumentError.new "Attempted to skip negative size: #{n}" if n < 0
    Skip(typeof(self), T).new(self, n)
  end

  def skip_while(&func : T -> U)
    SkipWhile(typeof(self), T, U).new(self, func)
  end

  def slice(n)
    raise ArgumentError.new "invalid slice size: #{n}" if n <= 0
    Slice(typeof(self), T).new(self, n)
  end

  def take(n)
    raise ArgumentError.new "Attempted to take negative size: #{n}" if n < 0
    Take(typeof(self), T).new(self, n)
  end

  def take_while(&func : T -> U)
    TakeWhile(typeof(self), T, U).new(self, func)
  end

  def tap(&block : T ->)
    Tap(typeof(self), T).new(self, block)
  end

  def uniq
    uniq &.itself
  end

  def uniq(&func : T -> U)
    Uniq(typeof(self), T, U).new(self, func)
  end

  def with_index(offset = 0)
    WithIndex(typeof(self), T).new(self, offset)
  end

  def with_object(obj)
    WithObject(typeof(self), T, typeof(obj)).new(self, obj)
  end

  def zip(other : Iterator(U))
    Zip(typeof(self), typeof(other), T, U).new(self, other)
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

  struct CompactMap(I, T, U)
    include Iterator(U)
    include IteratorWrapper

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

  # :nodoc:
  struct Map(I, T, U)
    include Iterator(U)
    include IteratorWrapper

    def initialize(@iterator : Iterator(T), @func : T -> U)
    end

    def next
      value = wrapped_next
      @func.call(value)
    end
  end

  # :nodoc:
  struct Select(I, T, B)
    include Iterator(T)
    include IteratorWrapper

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

  # :nodoc:
  struct Reject(I, T, B)
    include Iterator(T)
    include IteratorWrapper

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

  # :nodoc:
  class Take(I, T)
    include Iterator(T)
    include IteratorWrapper

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

  # :nodoc:
  class TakeWhile(I, T, U)
    include Iterator(T)
    include IteratorWrapper

    def initialize(@iterator : Iterator(T), @func: T -> U)
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

  # :nodoc:
  class Skip(I, T)
    include Iterator(T)
    include IteratorWrapper

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


  # :nodoc:
  class SkipWhile(I, T, U)
    include Iterator(T)
    include IteratorWrapper

    def initialize(@iterator : Iterator(T), @func: T -> U)
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

  # :nodoc:
  struct Zip(I1, I2, T1, T2)
    include Iterator({T1, T2})

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

  # :nodoc:
  struct Cycle(I, T)
    include Iterator(T)
    include IteratorWrapper

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

  # :nodoc:
  class CycleN(I, T, N)
    include Iterator(T)
    include IteratorWrapper

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

  # :nodoc:
  struct InGroupsOf(I, T, N, U)
    include Iterator(Array(T | U))
    include IteratorWrapper

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

  # :nodoc:
  class WithIndex(I, T)
    include Iterator({T, Int32})
    include IteratorWrapper

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

  # :nodoc:
  struct WithObject(I, T, O)
    include Iterator({T, O})
    include IteratorWrapper

    def initialize(@iterator : Iterator(T), @object : O)
    end

    def next
      v = wrapped_next
      {v, @object}
    end
  end

  # :nodoc:
  struct Slice(I, T)
    include Iterator(Array(T))
    include IteratorWrapper

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

  # :nodoc:
  struct Cons(I, T)
    include Iterator(Array(T))
    include IteratorWrapper

    def initialize(@iterator : Iterator(T), @n)
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

  # :nodoc:
  struct Uniq(I, T, U)
    include Iterator(T)
    include IteratorWrapper

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

  # :nodoc:
  class Chain(I1, I2, T1, T2)
    include Iterator(T1 | T2)

    def initialize(@iterator_1, @iterator_2)
      @iterator_1_consumed = false
    end

    def next
      if @iterator_1_consumed
        @iterator_2.next
      else
        value = @iterator_1.next
        if value.is_a?(Stop)
          @iterator_1_consumed = true
          value = @iterator_2.next
        end
        value
      end
    end

    def rewind
      @iterator_1.rewind
      @iterator_2.rewind
      @iterator_1_consumed = false
    end
  end

  # :nodoc:

  struct Singleton(T)
    include Iterator(T)

    def initialize(@element : T)
    end

    def next
      @element
    end

    def rewind
      self
    end
  end
  # :nodoc:
  struct SingletonProc(T)
    include Iterator(T)

    def initialize(@proc : -> T)
    end

    def next
      @proc.call
    end
  end

  # :nodoc:
  struct Tap(I, T)
    include Iterator(T)
    include IteratorWrapper

    def initialize(@iterator, @proc)
    end

    def next
      value = wrapped_next
      @proc.call(value)
      value
    end
  end
end
