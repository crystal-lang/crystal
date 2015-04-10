module Iterator(T)
  class Stop
    INSTANCE = new
  end

  def stop
    Stop::INSTANCE
  end

  include Enumerable(T)

  abstract def rewind

  def map(&func : T -> U)
    Map(typeof(self), T, U).new(self, func)
  end

  def select(&func : T -> _)
    Select(typeof(self), T).new(self, func)
  end

  def reject(&func : T -> _)
    Reject(typeof(self), T).new(self, func)
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

  def with_index
    WithIndex(typeof(self), T).new(self)
  end

  def each
    while true
      value = self.next
      break if value.is_a?(Stop)
      yield value
    end
  end

  struct Map(I, T, U)
    include Iterator(U)

    def initialize(@iter : Iterator(T), @func : T -> U)
    end

    def next
      value = @iter.next
      return stop if value.is_a?(Stop)
      @func.call(value)
    end
  end

  struct Select(I, T)
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
  end

  struct Reject(I, T)
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
  end

  class Take(I, T)
    include Iterator(T)

    def initialize(@iter : Iterator(T), @n : Int)
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
  end

  class Skip(I, T)
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

  struct Zip(I1, I2, T1, T2)
    include Iterator({T1, T2})

    def initialize(@iter1, @iter2)
    end

    def next
      v1 = @iter1.next
      return stop if v1.is_a?(Stop)

      v2 = @iter2.next
      return stop if v2.is_a?(Stop)

      {v1, v2}
    end
  end

  class Cycle(I, T)
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
  end

  class WithIndex(I, T)
    include Iterator({T, Int32})

    def initialize(@iterator : Iterator(T), @index = 0)
    end

    def next
      v = @iterator.next
      return stop if v.is_a?(Stop)

      value = {v, @index}
      @index += 1
      value
    end
  end
end

