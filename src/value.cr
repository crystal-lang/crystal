# Value is the base type of the primitive types (`Nil`, `Bool`, `Char`, `Number`),
# `Symbol`, `Pointer`, `Tuple`, `StaticArray` and all structs.
#
# A Value is passed by value: when you pass it to methods,
# return it from methods or assign it to variables, a copy
# of the value is actually passed.
# This is not important for nil, bools, integers, floats, symbols,
# pointers and tuples, because they are immutable, but with a mutable
# `Struct` or with a `StaticArray` you have to be careful. Read their
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
end
