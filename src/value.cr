# Value is the base type of the primitive types (Nil, Bool, Char, Int, Float),
# Symbol, Pointer, Tuple, StaticArray and all structs.
#
# As the name suggest, a Value is passed by value: when you pass it to methods
# or return it from methods, a copy of the value is actually passed.
#
# This is not important for nil, bools, integers, floats, symbols, pointers and tuples, because they are immutable,
# but with a mutable Struct or with a StaticArray you have to be careful. Read their
# documentation to learn more about this.
struct Value
  # Returns false.
  def ==(other)
    false
  end

  # Returns false.
  def !
    false
  end

  # Returns false.
  def nil?
    false
  end

  # Returns self.
  def clone
    self
  end
end

