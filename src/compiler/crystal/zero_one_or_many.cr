# An Array(T)-like type that's optimized for the case of
# frequently having zero or one elements.
struct Crystal::ZeroOneOrMany(T)
  include Indexable(T)

  getter value : Nil | T | Array(T)

  def initialize
    @value = nil
  end

  def initialize(@value : T)
  end

  def unsafe_fetch(index : Int)
    value = @value
    case value
    in Nil
      raise IndexError.new("Called ZeroOneOrMany#unsafe_fetch but value is nil")
    in T
      if index != 0
        raise IndexError.new("Called ZeroOneOrMany#unsafe_fetch with index != 0 but value is not an array")
      end

      value
    in Array(T)
      value.unsafe_fetch(index)
    end
  end

  def each(& : T ->)
    value = @value
    case value
    in Nil
      # Nothing to do
    in T
      yield value
    in Array(T)
      value.each do |element|
        yield element
      end
    end
  end

  def size : Int32
    value = @value
    case value
    in Nil
      0
    in T
      1
    in Array(T)
      value.size
    end
  end

  def <<(element : T) : self
    push(element)
  end

  def push(element : T) : self
    value = @value
    case value
    in Nil
      @value = element
    in T
      @value = [value, element] of T
    in Array(T)
      value.push element
    end
    self
  end

  def concat(elements : Indexable(T)) : self
    value = @value
    case value
    in Nil
      case elements.size
      when 0
        # Nothing to do
      when 1
        @value = elements.first
      else
        @value = elements.map(&.as(T)).to_a
      end
    in T
      new_value = Array(T).new(elements.size + 1)
      new_value.push(value)
      new_value.concat(elements)
      @value = new_value
    in Array(T)
      value.concat(elements)
    end
    self
  end

  def reject!(&block : T -> _) : self
    value = @value
    case value
    in Nil
      # Nothing to do
    in T
      if yield value
        @value = nil
      end
    in Array(T)
      value.reject! { |element| yield element }
      case value.size
      when 0
        @value = nil
      when 1
        @value = value.first
      end
    end
    self
  end
end
