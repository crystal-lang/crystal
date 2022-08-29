# An Array(T)-like type that's optimized for the case of
# frequently having zero or one elements.
#
# TODO: add tests for this type.
struct Crystal::ZeroOneOrMany(T)
  include Indexable(T)

  getter value : Nil | T | Array(T)

  def initialize
    @value = nil
  end

  def initialize(@value : T)
  end

  def initialize(values : Array(T))
    @value =
      case values.size
      when 0
        nil
      when 1
        values.first
      else
        values
      end
  end

  def unsafe_fetch(index : Int)
    value = @value
    case value
    in Nil
      raise "BUG: called ZeroOneOrMany#unsafe_fetch but value is nil"
    in T
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
        new_value = Array(T).new(elements.size)
        new_value.concat(elements)
        @value = new_value
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
    end
    self
  end
end
