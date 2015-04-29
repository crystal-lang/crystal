module Iterator(T)
  class Stop
    INSTANCE = new
  end

  def stop
    Stop::INSTANCE
  end

  include Enumerable(T)

  abstract def next
  abstract def rewind

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

  def uniq
    uniq &.itself
  end

  def uniq(&func : T -> U)
    Uniq(typeof(self), T, U).new(self, func)
  end

  # TODO: use default argument "offset" after 0.6.1, a bug prevents using it
  def with_index
    with_index 0
  end

  def with_index(offset)
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

    def rewind
      @iter.rewind
      self
    end
  end

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

    def rewind
      @iter1.rewind
      @iter2.rewind
      self
    end
  end

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
end

