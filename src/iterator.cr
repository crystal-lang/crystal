class StopIteration < Exception
  def initialize
    super("StopIteration")
  end
end

module Iterator(T)
  include Enumerable(T)

  def map(&func : T -> U)
    MapIterator(typeof(self), T, U).new(self, func)
  end

  def select(&func : T -> B)
    SelectIterator(typeof(self), T).new(self, func)
  end

  def reject(&func : T -> B)
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

  def initialize(@array : Array(T))
    @index = 0
  end

  def next
    if @index >= @array.length
      raise StopIteration.new
    end

    value = @array.buffer[@index]
    @index += 1
    value
  end
end

struct Range
  def iterator
    RangeIterator.new(self)
  end
end

class RangeIterator(T)
  include Iterator(T)

  def initialize(@range : Range(T))
    @current = range.begin
    @reached_end = false
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
end

struct MapIterator(I, T, U)
  include Iterator(U)

  def initialize(@iter : Iterator(T), @func : T -> U)
  end

  def next
    @func.call(@iter.next)
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
end

struct ZipIterator(I1, I2, T, U)
  include Iterator({T, U})

  def initialize(@iter1, @iter2)
  end

  def next
    {@iter1.next, @iter2.next}
  end
end
