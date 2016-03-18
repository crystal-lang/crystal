# A tuple is a fixed-size, immutable, stack-allocated sequence of values
# of possibly different types.
#
# A tuple can be created with the usual `new` method or with a tuple literal:
#
# ```
# tuple = {1, "hello", 'x'} # Tuple(Int32, String, Char)
# tuple[0]                  # => 1       (Int32)
# tuple[1]                  # => "hello" (String)
# tuple[2]                  # => 'x'     (Char)
# ```
#
# The compiler knows what types are in each position, so when indexing
# a tuple with an integer literal the compiler will return
# the value in that index and with the expected type, like in the above
# snippet. Indexing with an integer literal outside the bounds of the tuple
# will give a compile-time error.
#
# Indexing with an integer value that is only known at runtime will return
# a value whose type is the union of all the types in the tuple, and might raise
# `IndexError` .
#
# Tuples are the preferred way to return fixed-size multiple return
# values because no memory is needed to be allocated for them:
#
# ```
# def one_and_hello
#   {1, "hello"}
# end
#
# one, hello = one_and_hello
# one   # => 1
# hello # => "hello"
# ```
#
# Good examples of the above are `Number#divmod` and `Enumerable#minmax`.
#
# Tuples can be splat with the `*` operator and passed to methods:
#
# ```
# def multiply(string, value)
#   string * value
# end
#
# tuple = {"hey", 2}
# value = multiply(*tuple) # same as multiply tuple[0], tuple[1]
# value                    # => "heyhey"
# ```
#
# Finally, when using a splat argument in a method definition its type
# will be a tuple of the call arguments:
#
# ```
# def splat_test(*args)
#   args
# end
#
# tuple = splat_test 1, "hello", 'x'
# tuple # => {1, "hello", 'x'} (Tuple(Int32, String, Char))
# ```
struct Tuple
  include Enumerable(typeof((i = 0; self[i])))
  include Iterable
  include Comparable(Tuple)

  # Creates a tuple that will contain the given arguments.
  #
  # This method is useful in macors and generic code because with it you can
  # creates empty tuples, something that you can't do with a tuple literal.
  #
  # ```
  # Tuple.new(1, "hello", 'x') #=> {1, "hello", 'x'}
  # Tuple.new                  #=> {}
  #
  # {}                         # syntax error
  # ```
  def self.new(*args)
    args
  end

  # Returns the element at the given index. Read the type docs to understand
  # the difference between indexing with a number literal or a variable.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple[0] # => 1 (Int32)
  # tuple[3] # => compile error: index out of bounds for tuple {Int32, String, Char}
  #
  # i = 0
  # tuple[i] # => 1 (Int32 | String | Char)
  #
  # i = 3
  # tuple[i] # => runtime error: IndexError
  # ```
  def [](index : Int)
    at(index)
  end

  # Returns the element at the given index or `nil` if out of bounds.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple[0] # => 1
  # tuple[3] # => nil
  # ```
  def []?(index : Int)
    at(index) { nil }
  end

  # Returns the element at the given index or raises IndexError if out of bounds.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple[0] # => 1
  # tuple[3] # => raises IndexError
  # ```
  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  # Returns the element at the given index or the value returned by the block if
  # out of bounds.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.at(0) { 10 } # => 1
  # tuple.at(3) { 10 } # => 10
  # ```
  def at(index : Int)
    {% for i in 0...@type.size %}
      return self[{{i}}] if {{i}} == index
    {% end %}
    yield
  end

  # Returns a tuple populated with the elements at the given indexes.
  # Raises if any index is invalid.
  #
  # ```
  # {"a", "b", "c", "d"}.values_at(0, 2) # => {"a", "c"}
  # ```
  def values_at(*indexes : Int)
    indexes.map { |index| self[index] }
  end

  # Yields each of the elements in this tuple.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.each do |value|
  #   puts value
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 1
  # "hello"
  # 'x'
  # ```
  def each
    {% for i in 0...@type.size %}
      yield self[{{i}}]
    {% end %}
    self
  end

  # Returns an `Iterator` for the elements in this tuple.
  #
  # ```
  # {1, 'a'}.each.cycle.first(3).to_a # => [1, 'a', 1]
  # ```
  def each
    ItemIterator(self, typeof((i = 0; self[i]))).new(self)
  end

  # Returns `true` if this tuple has the same size as the other tuple
  # and their elements are equal to each other when  compared with `==`.
  #
  # ```crystal
  # t1 = {1, "hello"}
  # t2 = {1.0, "hello"}
  # t3 = {2, "hello"}
  #
  # t1 == t2 # => true
  # t1 == t3 # => false
  # ```
  def ==(other : self)
    {% for i in 0...@type.size %}
      return false unless self[{{i}}] == other[{{i}}]
    {% end %}
    true
  end

  # ditto
  def ==(other : Tuple)
    return false unless size == other.size

    size.times do |i|
      return false unless self[i] == other[i]
    end
    true
  end

  # Returns `true` if case equality holds for the elements in `self` and *other*.
  #
  # ```
  # {1, 2} === {1, 2} # => true
  # {1, 2} === {1, 3} # => false
  # ```
  #
  # See `Object#===`
  def ===(other : self)
    {% for i in 0...@type.size %}
      return false unless self[{{i}}] === other[{{i}}]
    {% end %}
    true
  end

  # Returns `true` if `self` and *other* have the same size and case equality holds
  # for the elements in `self` and *other*.
  #
  # ```
  # {1, 2} === {1, 2, 3}             # => false
  # {/o+/, "bar"} === {"foo", "bar"} # => true
  # ```
  #
  # See `Object#===`
  def ===(other : Tuple)
    return false unless size == other.size

    size.times do |i|
      return false unless self[i] === other[i]
    end
    true
  end

  # Implements the comparison operator.
  #
  # Each object in each tuple is compared (using the <=> operator).
  #
  # Tuples are compared in an "element-wise" manner; the first element of this tuple is
  # compared with the first one of `other` using the `<=>` operator, then each of the second elements,
  # etc. As soon as the result of any such comparison is non zero
  # (i.e. the two corresponding elements are not equal), that result is returned for the whole tuple comparison.
  #
  #
  # If all the elements are equal, then the result is based on a comparison of the tuple sizes.
  # Thus, two tuples are "equal" according to `<=>` if, and only if, they have the same size
  # and the value of each element is equal to the value of the corresponding element in the other tuple.
  #
  # ```
  # {"a", "a", "c"} <=> {"a", "b", "c"} # => -1
  # {1, 2, 3, 4, 5, 6} <=> {1, 2}       # => +1
  # {1, 2} <=> {1, 2.0}                 # => 0
  # ```
  #
  # See `Object#<=>`.
  def <=>(other : self)
    {% for i in 0...@type.size %}
      cmp = self[{{i}}] <=> other[{{i}}]
      return cmp unless cmp == 0
    {% end %}
    0
  end

  # ditto
  def <=>(other : Tuple)
    min_size = Math.min(size, other.size)
    min_size.times do |i|
      cmp = self[i] <=> other[i]
      return cmp unless cmp == 0
    end
    size <=> other.size
  end

  # returns a hash value based on this tuple's length and contents.
  #
  # see `object#hash`.
  def hash
    hash = 31 * size
    {% for i in 0...@type.size %}
      hash = 31 * hash + self[{{i}}].hash
    {% end %}
    hash
  end

  # Returns self.
  def dup
    self
  end

  # Returns a tuple containing cloned elements of this tuple using the `clone` method.
  def clone
    {% if true %}
      Tuple.new(
        {% for i in 0...@type.size %}
          self[{{i}}].clone,
        {% end %}
      )
    {% end %}
  end

  # Returns true if this tuple is empty.
  #
  # ```
  # Tuple.new.empty? # => true
  # {1, 2}.empty?    # => false
  # ```
  def empty?
    size == 0
  end

  # Returns the number of elements in this tuple.
  #
  # ```
  # {'a', 'b'}.size # => 2
  # ```
  def size
    {{@type.size}}
  end

  # Returns a tuple containing the types of this tuple.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.types # => {Int32, String, Char}
  # ```
  def types
    T
  end

  # Same as `to_s`.
  def inspect
    to_s
  end

  # Appends a string representation of this tuple to the given `IO`.
  #
  # ```
  # tuple = {1, "hello"}
  # tuple.to_s # => "{1, \"hello\"}"
  # ```
  def to_s(io)
    io << "{"
    join ", ", io, &.inspect(io)
    io << "}"
  end

  # Returns a new tuple where elements are mapped by the given block.
  #
  # ```
  # tuple = {1, 2.5, "a"}
  # tuple.map &.to_s # => {"1", "2.5", "a"}
  # ```
  def map
    {% if true %}
      Tuple.new(
        {% for i in 0...@type.size %}
          (yield self[{{i}}]),
        {% end %}
      )
   {% end %}
  end

  # Returns a new tuple where the elements are in reverse order.
  #
  # ```
  # tuple = {1, 2.5, "a"}
  # tuple.reverse # => {"a", 2.5, 1}
  # ```
  def reverse
    {% if true %}
      Tuple.new(
        {% for i in 1..@type.size %}
          self[{{@type.size - i}}],
        {% end %}
      )
    {% end %}
  end

  # Yields each of the elements in this tuple in reverse order.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.reverse_each do |value|
  #   puts value
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 'x'
  # "hello"
  # 1
  # ```
  def reverse_each
    {% for i in 1..@type.size %}
      yield self[{{@type.size - i}}]
    {% end %}
    self
  end

  # Returns an `Iterator` for the elements in this tuple.
  #
  # ```
  # {1, 'a'}.reverse_each.cycle.first(3).to_a # => [1, 'a', 1]
  # ```
  def reverse_each
    ReverseIterator(self, typeof((i = 0; self[i]))).new(self)
  end

  # Returns the first element of this tuple. Doesn't compile
  # if the tuple is empty.
  #
  # ```
  # tuple = {1, 2.5}
  # tuple.first # => 1
  # ```
  def first
    self[0]
  end

  # Returns the first element of this tuple, or nil if this
  # is the empty tuple.
  # ```
  # tuple = {1, 2.5}
  # tuple.first? # => 1
  #
  # empty = Tuple.new
  # empty.first? # => nil
  # ```
  def first?
    {% if @type.size == 0 %}
      nil
    {% else %}
      self[0]
    {% end %}
  end

  # Returns the last element of this tuple. Doesn't compile
  # if the tuple is empty.
  #
  # ```
  # tuple = {1, 2.5}
  # tuple.last # => 2.5
  # ```
  def last
    {% if true %}
      self[{{@type.size - 1}}]
    {% end %}
  end

  # Returns the last element of this tuple, or nil if this
  # is the empty tuple.
  #
  # ```
  # tuple = {1, 2.5}
  # tuple.last? # => 2.5
  #
  # empty = Tuple.new
  # empty.last? # => nil
  # ```
  def last?
    {% if @type.size == 0 %}
      nil
    {% else %}
      self[{{@type.size - 1}}]
    {% end %}
  end

  class ItemIterator(I, T)
    include Iterator(T)

    @tuple : I
    @index : Int32

    def initialize(@tuple, @index = 0)
    end

    def next
      value = @tuple.at(@index) { stop }
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end

  # :nodoc:
  class ReverseIterator(I, T)
    include Iterator(T)

    @tuple : I
    @index : Int32

    def initialize(@tuple, @index = tuple.size - 1)
    end

    def next
      return stop if @index < 0

      value = @tuple.at(@index) { stop }
      @index -= 1
      value
    end

    def rewind
      @index = @tuple.size - 1
      self
    end
  end
end
