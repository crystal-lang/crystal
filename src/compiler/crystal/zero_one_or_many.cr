# An Array(T)-like type that's optimized for the case of
# frequently having zero or one elements.
#
# It's a struct, so if you have a ZeroOneOrMany and you
# want to mutate, you have to use `with` or `without`
# and overwrite the value you have with what you get
# from those methods.
#
# Warning: you should never keep the original value
# around when using the above methods as the internal
# array might be mutated (for performance reasons),
# so the original value might mutate in that case!
#
# TODO: add tests for this type.
struct ZeroOneOrMany(T)
  include Enumerable(T)

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

  def with(element : T) : ZeroOneOrMany(T)
    value = @value
    case value
    in Nil
      ZeroOneOrMany(T).new(element)
    in T
      ZeroOneOrMany(T).new([value, element] of T)
    in Array(T)
      value.push element
      self
    end
  end

  def with(elements : Enumerable(T)) : ZeroOneOrMany(T)
    value = @value
    case value
    in Nil
      ZeroOneOrMany(T).new(elements.map(&.as(T)))
    in T
      new_elements = Array(T).new(elements.size + 1)
      new_elements.push(value)
      new_elements.concat(elements)
      ZeroOneOrMany.new(new_elements)
    in Array(T)
      value.concat(elements)
      self
    end
  end

  def without(element : T) : ZeroOneOrMany(T)
    value = @value
    case value
    in Nil
      self
    in T
      if value.same?(element)
        ZeroOneOrMany(T).new
      else
        self
      end
    in Array(T)
      value.reject!(&.same?(element))
      ZeroOneOrMany(T).new(value)
    end
  end

  def without(elements : Enumerable(T)) : ZeroOneOrMany(T)
    value = @value
    case value
    in Nil
      self
    in T
      if elements.any? &.same?(value)
        ZeroOneOrMany(T).new
      else
        self
      end
    in Array(T)
      value.reject! { |element| elements.any? &.same?(element) }
      ZeroOneOrMany(T).new(value)
    end
  end
end
