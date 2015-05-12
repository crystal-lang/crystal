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

  # Returns the next element in this iterator, or `Iterator::Stop::INSTANCE` if there
  # are no more elements.
  abstract def next

  # Rewinds the iterator to its original state.
  abstract def rewind

  def each
    self
  end

  def map(&func : T -> U)
    Map(typeof(self), T, U).new(self, func)
  end

  def select(&func : T -> U)
    Select(typeof(self), T, U).new(self, func)
  end

  def reject(&func : T -> U)
    Reject(typeof(self), T, U).new(self, func)
  end

  def take(n)
    Take(typeof(self), T).new(self, n)
  end

  def skip(n)
    Skip(typeof(self), T).new(self, n)
  end

  def zip(other : Iterator(U))
    Zip(typeof(self), typeof(other), T, U).new(self, other)
  end

  def cycle
    Cycle(typeof(self), T).new(self)
  end

  def cycle(n : Int)
    CycleN(typeof(self), T, typeof(n)).new(self, n)
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

  def slice(n)
    raise ArgumentError.new "invalid slice size: #{n}" if n <= 0

    Slice(typeof(self), T).new(self, n)
  end

  def each_slice(n)
    slice(n)
  end

  def cons(n)
    raise ArgumentError.new "invalid cons size: #{n}" if n <= 0

    Cons(typeof(self), T).new(self, n)
  end

  def chain(other : Iterator(U))
    Chain(typeof(self), typeof(other), T, U).new(self, other)
  end

  def tap(&block : T ->)
    Tap(typeof(self), T).new(self, block)
  end

  def self.of(element : T)
    Singleton(T).new(element)
  end

  def self.of(&block : -> T)
    SingletonProc(T).new(block)
  end

  def each
    while true
      value = self.next
      break if value.is_a?(Stop)
      yield value
    end
  end

  # :nodoc:
  struct Map(I, T, U)
    include Iterator(U)

    def initialize(@iter : Iterator(T), @func : T -> U)
    end

    def next
      value = @iter.next
      return stop if value.is_a?(Stop)
      @func.call(value)
    end

    def rewind
      @iter.rewind
      self
    end
  end

  # :nodoc:
  struct Select(I, T, B)
    include Iterator(T)

    def initialize(@iter : Iterator(T), @func : T -> B)
    end

    def next
      while true
        value = @iter.next
        return stop if value.is_a?(Stop)

        if @func.call(value)
          return value
        end
      end
    end

    def rewind
      @iter.rewind
      self
    end
  end

  # :nodoc:
  struct Reject(I, T, B)
    include Iterator(T)

    def initialize(@iter : Iterator(T), @func : T -> B)
    end

    def next
      while true
        value = @iter.next
        return stop if value.is_a?(Stop)

        unless @func.call(value)
          return value
        end
      end
    end

    def rewind
      @iter.rewind
      self
    end
  end

  # :nodoc:
  class Take(I, T)
    include Iterator(T)

    def initialize(@iter : Iterator(T), @n : Int)
      @original = @n
    end

    def next
      if @n > 0
        value = @iter.next
        return stop if value.is_a?(Stop)

        @n -= 1
        value
      else
        stop
      end
    end

    def rewind
      @iter.rewind
      @n = @original
      self
    end
  end

  # :nodoc:
  class Skip(I, T)
    include Iterator(T)

    def initialize(@iter : Iterator(T), @n : Int)
      @original = @n
    end

    def next
      while @n > 0
        @iter.next
        @n -= 1
      end
      @iter.next
    end

    def rewind
      @iter.rewind
      @n = @original
      self
    end
  end

  # :nodoc:
  struct Zip(I, J, T, U)
    include Iterator({T, U})

    def initialize(@iter1, @iter2)
    end

    def next
      v1 = @iter1.next
      return stop if v1.is_a?(Stop)

      v2 = @iter2.next
      return stop if v2.is_a?(Stop)

      {v1, v2}
    end

    def rewind
      @iter1.rewind
      @iter2.rewind
      self
    end
  end

  # :nodoc:
  struct Cycle(I, T)
    include Iterator(T)

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

    def rewind
      @iterator.rewind
      self
    end
  end

  # :nodoc:
  class CycleN(I, T, N)
    include Iterator(T)

    def initialize(@iterator : Iterator(T), @n : N)
      @count = 0
    end

    def next
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
      @iterator.rewind
      @count = 0
      self
    end
  end

  # :nodoc:
  class WithIndex(I, T)
    include Iterator({T, Int32})

    def initialize(@iterator : Iterator(T), @offset, @index = offset)
    end

    def next
      v = @iterator.next
      return stop if v.is_a?(Stop)

      value = {v, @index}
      @index += 1
      value
    end

    def rewind
      @iterator.rewind
      @index = @offset
      self
    end
  end

  # :nodoc:
  struct WithObject(I, T, O)
    include Iterator({T, O})

    def initialize(@iterator : Iterator(T), @object : O)
    end

    def next
      v = @iterator.next
      return stop if v.is_a?(Stop)

      {v, @object}
    end

    def rewind
      @iterator.rewind
      self
    end
  end

  # :nodoc:
  struct Slice(I, T)
    include Iterator(Array(T))

    def initialize(@iterator : Iterator(T), @n)
    end

    def next
      values = Array(T).new(@n)
      @n.times do
        value = @iterator.next
        if value.is_a?(Stop)
          break
        else
          values << value
        end
      end

      if values.empty?
        stop
      else
        values
      end
    end

    def rewind
      @iterator.rewind
      self
    end
  end

  # :nodoc:
  struct Cons(I, T)
    include Iterator(Array(T))

    def initialize(@iterator : Iterator(T), @n)
      @values = Array(T).new(@n)
    end

    def next
      loop do
        elem = @iterator.next
        return stop if elem.is_a?(Stop)
        @values << elem
        @values.shift if @values.size > @n
        break if @values.size == @n
      end
      @values.dup
    end

    def rewind
      @iterator.rewind
      @values = Array(T).new(@n)
      self
    end
  end

  # :nodoc:
  struct Uniq(I, T, U)
    include Iterator(T)

    def initialize(@iterator : Iterator(T), @func : T -> U)
      @hash = {} of T => Bool
    end

    def next
      while true
        value = @iterator.next
        if value.is_a?(Stop)
          return stop
        end

        transformed = @func.call value

        unless @hash[transformed]?
          @hash[transformed] = true
          return value
        end
      end
    end

    def rewind
      @iterator.rewind
      @hash.clear
    end
  end

  # :nodoc:
  class Chain(I, J, T, U)
    include Iterator(T | U)

    def initialize(@iter1, @iter2)
      @iter1_consumed = false
    end

    def next
      if @iter1_consumed
        @iter2.next
      else
        value = @iter1.next
        if value.is_a?(Stop)
          @iter1_consumed = true
          value = @iter2.next
        end
        value
      end
    end

    def rewind
      @iter1.rewind
      @iter2.rewind
      @iter1_consumed = false
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

    def initialize(@iter, @proc)
    end

    def next
      value = @iter.next
      if value.is_a?(Stop)
        stop
      else
        @proc.call(value)
        value
      end
    end

    def rewind
      @iter.rewind
      self
    end
  end
end

