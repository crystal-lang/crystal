class StopIteration < Exception
  def initialize
    super("StopIteration")
  end
end

module Iterator(T)
  include Enumerable(T)

  def map(&func : T -> _)
    MapIterator(typeof(self), T, typeof(func.call(first))).new(self, func)
  end

  def select(&func : T -> _)
    SelectIterator(typeof(self), T).new(self, func)
  end

  def reject(&func : T -> _)
    RejectIterator(typeof(self), T).new(self, func)
  end

  def take(n)
    TakeIterator(typeof(self), T).new(self, n)
  end

  def skip(n)
    SkipIterator(typeof(self), T).new(self, n)
  end

  def zip(other : Iterator(U))
    ZipIterator(typeof(self), typeof(other), T, U).new(self, other)
  end

  def cycle
    CycleIterator(typeof(self), T).new(self)
  end

  def with_index
    WithIndexIterator(typeof(self), T).new(self)
  end

  def each
    while value = self.next
      yield value
    end
  rescue StopIteration
  end
end

class Array
  def iterator
    ArrayIterator.new(self)
  end
end

class ArrayIterator(T)
  include Iterator(T)

  def initialize(@array : Array(T), @index = 0)
  end

  def next
    if @index >= @array.length
      raise StopIteration.new
    end

    value = @array.buffer[@index]
    @index += 1
    value
  end

  def clone
    ArrayIterator(T).new(@array, @index)
  end
end

struct Range
  def iterator
    RangeIterator.new(self)
  end
end

class RangeIterator(T)
  include Iterator(T)

  def initialize(@range : Range(T), @current = range.begin, @reached_end = false)
  end

  def next
    if @reached_end
      raise StopIteration.new
    end

    if @current == @range.end
      @reached_end = true

      if @range.excludes_end?
        raise StopIteration.new
      else
        return @current
      end
    else
      value = @current
      @current = @current.succ
      value
    end
  end

  def clone
    RangeIterator(T).new(@range, @current, @reached_end)
  end
end

struct MapIterator(I, T, U)
  include Iterator(U)

  def initialize(@iter : Iterator(T), @func : T -> U)
  end

  def next
    @func.call(@iter.next)
  end

  def clone
    MapIterator.new(@iter.clone, @func)
  end
end

struct SelectIterator(I, T)
  include Iterator(T)

  def initialize(@iter : Iterator(T), @func : T -> B)
  end

  def next
    while true
      value = @iter.next
      if @func.call(value)
        return value
      end
    end
  end

  def clone
    SelectIterator(I, T).new(@iter.clone, @func)
  end
end

struct RejectIterator(I, T)
  include Iterator(T)

  def initialize(@iter : Iterator(T), @func : T -> B)
  end

  def next
    while true
      value = @iter.next
      unless @func.call(value)
        return value
      end
    end
  end

  def clone
    RejectIterator(I, T).new(@iter.clone, @func)
  end
end

struct TakeIterator(I, T)
  include Iterator(T)

  def initialize(@iter : Iterator(T), @n : Int)
  end

  def next
    if @n > 0
      value = @iter.next
      @n -= 1
      value
    else
      raise StopIteration.new
    end
  end

  def clone
    TakeIterator(I, T).new(@iter.clone, @n)
  end
end

struct SkipIterator(I, T)
  include Iterator(T)

  def initialize(@iter : Iterator(T), @n : Int)
  end

  def next
    while @n > 0
      @iter.next
      @n -= 1
    end
    @iter.next
  end

  def clone
    SkipIterator(I, T).new(@iter.clone, @n)
  end
end

struct ZipIterator(I1, I2, T1, T2)
  include Iterator({T1, T2})

  def initialize(@iter1, @iter2)
  end

  def next
    {@iter1.next, @iter2.next}
  end

  def clone
    ZipIterator(I1, I2, T1, T2).new(@iter1.clone, @iter2.clone)
  end
end

class CycleIterator(I, T)
  include Iterator(T)

  def initialize(@iterator : Iterator(T))
    @original = @iterator.clone
  end

  def next
    @iterator.next
  rescue StopIteration
    @iterator = @original.clone
    @iterator.next
  end
end

class WithIndexIterator(I, T)
  include Iterator({T, Int32})

  def initialize(@iterator : Iterator(T), @index = 0)
  end

  def next
    value = {@iterator.next, @index}
    @index += 1
    value
  end

  def clone
    WithIndexIterator(I, T).new(@iterator.clone, @index)
  end
end

