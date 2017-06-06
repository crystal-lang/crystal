# A mutable object that optionally contains a value. The two states
# are 'some' (has a value) and 'none' (has no value). Acts as a
# replacement for `Nil` with better type checking, and as a general
# replacement for the Null Object pattern. A common use case is as the
# return for an operation that may fail, but for which no error
# information is necessary.
class Optional(T)
  include Comparable(self)

  # The current value. Will be `Nil` when 'none'.
  getter value

  # True if a value has been set.
  def some?
    @exists
  end

  # True when no value has been set.
  def none?
    !@exists
  end

  # Compare the current value to the *other* value. Will never be equal
  # when 'none'.
  def <=>(other : T)
    none? ? -1 : (@value.not_nil! <=> other)
  end

  # Compare the current value to the *other* value. Will never be equal
  # when 'none'. Two 'none' objects will not be equal, since 'none'
  # represents the absence of any value.
  def <=>(other : Optional(T))
    if none?
      -1
    elsif some? && other.none?
      1
    else
      @value.not_nil! <=> other.value.not_nil!
    end
  end

  def <(other : Optional(T))
    (self <=> other) < 0
  end

  def <=(other : Optional(T))
    (self <=> other) <= 0
  end

  def ==(other : Optional(T))
    (self <=> other) == 0
  end

  def >=(other : Optional(T))
    (self <=> other) >= 0
  end

  def >(other : Optional(T))
    (self <=> other) > 0
  end

  # Returns the current value when 'some' else returns the *other* value.
  def value_or(other : T)
    if @exists
      @value.not_nil!
    else
      other
    end
  end

  # When 'some' will return the current value. When 'none' will
  # call the block and will return the result returned by the block.
  def value_or(&block : -> T)
    value_or(yield)
  end

  # When 'some' will call the block with the given value. When 'none'
  # will do nothing, just return. This is a convenience replacement
  # for checking the state via predicate.
  def if_value(&block : T -> Nil)
    if @exists
      yield(@value.not_nil!)
    end
    nil
  end

  # Set the current value to the given value and become 'some'.
  def set(@value : T)
    @exists = true
    @value
  end

  # Set the current value to the result of the block operation and
  # become 'some'.
  def set(&block : -> T)
    set(yield)
  end

  # Clear the value and set to 'none'.
  def reset
    @exists = false
    @value = nil
  end

  # When 'some', apply the block operation to the current value
  # and set the new value to the value returned by the block.
  # Do nothing when 'none'.
  def apply(&block : T -> T)
    if some?
      set(yield(@value.not_nil!))
    end

    nil
  end

  # Replace the current value with that of other, and replace the
  # value of other with the current value. If either is 'none' the
  # other becomes 'none'. Does nothing when both are 'none'.
  def swap(other : Optional(T))
    if some? && other.some?
      tmp = other.value
      other.set(@value.not_nil!)
      @value = tmp
    elsif some? # && other.none?
      other.set(@value.not_nil!)
      reset
    elsif other.some? # && none?
      set(other.value.not_nil!)
      other.reset
    end

    nil
  end

  # Create a 'some' with the given value.
  def self.some(value : T)
    Optional(T).new(value)
  end

  # Create a 'none'.
  def self.none
    Optional(T).new
  end

  # Create a 'some' with the given value.
  def initialize(value : T?)
    if value
      set(value)
    else
      reset
    end
  end

  # Set the current value to the result of the block. Become 'some'
  # if the block returns a value, become 'none' if the block returns
  # `Nil`.
  def initialize(&block : -> T?)
    value = yield
    value ? set(value) : reset
  end

  # Create a 'none'.
  def initialize
    reset
  end

  @exists : (Bool)?
end
