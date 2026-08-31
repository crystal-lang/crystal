# A tuple is a fixed-size, immutable, stack-allocated sequence of values
# of possibly different types.
#
# You can think of a `Tuple` as an immutable `Array` whose types for each position
# are known at compile time.
#
# A tuple can be created with the usual `new` method or with a tuple literal:
#
# ```
# tuple = {1, "hello", 'x'} # Tuple(Int32, String, Char)
# tuple[0]                  # => 1
# tuple[1]                  # => "hello"
# tuple[2]                  # => 'x'
# ```
#
# See [`Tuple` literals](https://crystal-lang.org/reference/syntax_and_semantics/literals/tuple.html) in the language reference.
#
# The compiler knows what types are in each position, so when indexing
# a tuple with an integer literal the compiler will return
# the value in that index and with the expected type, like in the above
# snippet. Indexing with an integer literal outside the bounds of the tuple
# will give a compile-time error.
#
# Indexing with an integer value that is only known at runtime will return
# a value whose type is the union of all the types in the tuple, and might raise
# `IndexError`.
#
# Indexing with `#[]?` does not make the return value nilable if the index is
# known to be within bounds:
#
# ```
# tuple = {1, "hello", 'x'}
# tuple[0]?         # => 1
# typeof(tuple[0]?) # => Int32
# ```
#
# Indexing with a range literal known at compile-time is also allowed, and the
# returned value will have the correct sub-tuple type:
#
# ```
# tuple = {1, "hello", 'x'} # Tuple(Int32, String, Char)
# sub = tuple[0..1]         # => {1, "hello"}
# typeof(sub)               # => Tuple(Int32, String)
# ```
#
# `Tuple`'s own instance classes may also be indexed in a similar manner,
# returning their element types instead:
#
# ```
# tuple = Tuple(Int32, String, Char)
# tuple[0]   # => Int32
# tuple[3]?  # => nil
# tuple[1..] # => Tuple(String, Char)
# ```
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
# tuple.class # => Tuple(Int32, String, Char)
# tuple       # => {1, "hello", 'x'}
# ```
struct Tuple
  include Indexable(Union(*T))
  include Comparable(Tuple)

  # Creates a tuple that will contain the given values.
  #
  # This method is useful in macros and generic code because with it you can
  # create empty tuples, something that you can't do with a tuple literal.
  #
  # ```
  # Tuple.new(1, "hello", 'x') #=> {1, "hello", 'x'}
  # Tuple.new                  #=> {}
  #
  # {}                         # syntax error
  # ```
  def self.new(*args : *T)
    {% if @type.name(generic_args: false) == "Tuple" %}
      # deduced type vars
      args
    {% elsif @type.name(generic_args: false) == "Tuple()" %}
      # special case: empty tuple
      # TODO: check against `Tuple()` directly after 1.4.0
      args
    {% else %}
      # explicitly provided type vars
      # following `typeof` is needed to access private types
      {% begin %}
        {
          {% for i in 0...@type.size %}
            args[{{ i }}].as(typeof(element_type({{ i }}))),
          {% end %}
        }
      {% end %}
    {% end %}
  end

  # Creates a tuple from the given array, with elements casted to the given types.
  #
  # ```
  # Tuple(String, Int64).from(["world", 2_i64])       # => {"world", 2_i64}
  # Tuple(String, Int64).from(["world", 2_i64]).class # => Tuple(String, Int64)
  # ```
  #
  # See also: `#from`.
  def self.from(array : Array) : self
    {% begin %}
    Tuple.new(*{{ T }}).from(array)
    {% end %}
  end

  # Expects to be called on a tuple of types, creates a tuple from the given array,
  # with types casted appropriately.
  #
  # This allows you to easily pass an array as individual arguments to a method.
  #
  # ```
  # require "json"
  #
  # def speak_about(thing : String, n : Int64)
  #   "I see #{n} #{thing}s"
  # end
  #
  # data = JSON.parse(%(["world", 2])).as_a.map(&.raw)
  # speak_about(*{String, Int64}.from(data)) # => "I see 2 worlds"
  # ```
  def from(array : Array)
    if size != array.size
      raise ArgumentError.new "Expected array of size #{size} but one of size #{array.size} was given."
    end

    {% begin %}
    Tuple.new(
    {% for i in 0...@type.size %}
      self[{{ i }}].cast(array[{{ i }}]),
    {% end %}
    )
    {% end %}
  end

  def unsafe_fetch(index : Int)
    self[index]
  end

  # Returns the element at the given *index*. Read the type docs to understand
  # the difference between indexing with a number literal or a variable.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple[0]         # => 1
  # typeof(tuple[0]) # => Int32
  # tuple[3]         # Error: index out of bounds for Tuple(Int32, String, Char) (3 not in -3..2)
  #
  # i = 0
  # tuple[i]         # => 1
  # typeof(tuple[i]) # => (Char | Int32 | String)
  #
  # i = 3
  # tuple[i] # raises IndexError
  # ```
  def [](index : Int)
    at(index)
  end

  # Returns the element type at the given *index*. Read the type docs to
  # understand the difference between indexing with a number literal or a
  # variable.
  #
  # ```
  # alias Foo = Tuple(Int32, String)
  # Foo[0]      # => Int32
  # Foo[0].zero # => 0
  # Foo[2]      # Error: index out of bounds for Tuple(Int32, String).class (2 not in -2..1)
  #
  # i = 0
  # Foo[i]      # => Int32
  # Foo[i].zero # Error: undefined method 'zero' for String.class (compile-time type is (Int32.class | String.class))
  #
  # i = 2
  # Foo[i] # raises IndexError
  # ```
  def self.[](index : Int)
    self[index]? || raise IndexError.new
  end

  # Returns the element at the given *index* or `nil` if out of bounds. Read the
  # type docs to understand the difference between indexing with a number
  # literal or a variable.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple[0]?         # => 1
  # typeof(tuple[0]?) # => Int32
  # tuple[3]?         # => nil
  # typeof(tuple[3]?) # => Nil
  #
  # i = 0
  # tuple[i]?         # => 1
  # typeof(tuple[i]?) # => (Char | Int32 | String | Nil)
  #
  # i = 3
  # tuple[i]? # => nil
  # ```
  def []?(index : Int)
    at(index) { nil }
  end

  # Returns the element type at the given *index* or `nil` if out of bounds.
  # Read the type docs to understand the difference between indexing with a
  # number literal or a variable.
  #
  # ```
  # alias Foo = Tuple(Int32, String)
  # Foo[0]?         # => Int32
  # Foo[0]?.zero    # => 0
  # Foo[2]?         # => nil
  # typeof(Foo[2]?) # => Nil
  #
  # i = 0
  # Foo[i]?      # => Int32
  # Foo[i]?.zero # Error: undefined method 'zero' for String.class (compile-time type is (Int32.class | String.class | Nil))
  #
  # i = 2
  # Foo[i]? # => nil
  # ```
  def self.[]?(index : Int)
    # following `typeof` is needed to access private types
    {% begin %}
      case index
      {% for i in 0...T.size %}
      when {{ i }}, {{ i - T.size }}
        typeof(element_type({{ i }}))
      {% end %}
      end
    {% end %}
  end

  # Returns all elements that are within the given *range*. *range* must be a
  # range literal whose value is known at compile-time.
  #
  # Negative indices count backward from the end of the tuple (-1 is the last
  # element). Additionally, an empty tuple is returned when the starting index
  # for an element range is at the end of the tuple.
  #
  # Raises a compile-time error if `range.begin` is out of range.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple[0..1] # => {1, "hello"}
  # tuple[-2..] # => {"hello", 'x'}
  # tuple[...1] # => {1}
  # tuple[4..]  # Error: begin index out of bounds for Tuple(Int32, String, Char) (4 not in -3..3)
  #
  # i = 0
  # tuple[i..2] # Error: Tuple#[](Range) can only be called with range literals known at compile-time
  #
  # i = 0..2
  # tuple[i] # Error: Tuple#[](Range) can only be called with range literals known at compile-time
  # ```
  def [](range : Range)
    {% raise "Tuple#[](Range) can only be called with range literals known at compile-time" %}
  end

  # Returns all element types that are within the given *range*. *range* must be
  # a range literal whose value is known at compile-time.
  #
  # Negative indices count backward from the end of the tuple (-1 is the last
  # element). Additionally, an empty tuple is returned when the starting index
  # for an element range is at the end of the tuple.
  #
  # Raises a compile-time error if `range.begin` is out of range.
  #
  # ```
  # alias Foo = Tuple(Int32, String, Char)
  # Foo[0..1] # => Tuple(Int32, String)
  # Foo[-2..] # => Tuple(String, Char)
  # Foo[...1] # => Tuple(Int32)
  # Foo[4..]  # Error: begin index out of bounds for Tuple(Int32, String, Char).class (4 not in -3..3)
  #
  # i = 0
  # Foo[i..2] # Error: Tuple.[](Range) can only be called with range literals known at compile-time
  #
  # i = 0..2
  # Foo[i] # Error: Tuple.[](Range) can only be called with range literals known at compile-time
  # ```
  def self.[](range : Range)
    {% raise "Tuple.[](Range) can only be called with range literals known at compile-time" %}
  end

  # Returns the element at the given *index* or raises IndexError if out of bounds.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.at(0) # => 1
  # tuple.at(3) # raises IndexError
  # ```
  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  # Returns the element at the given *index* or the value returned by the block if
  # out of bounds.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.at(0) { 10 } # => 1
  # tuple.at(3) { 10 } # => 10
  # ```
  def at(index : Int, &)
    index += size if index < 0
    {% for i in 0...T.size %}
      return self[{{ i }}] if {{ i }} == index
    {% end %}
    yield
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
  def each(& : Union(*T) ->) : Nil
    {% for i in 0...T.size %}
      yield self[{{ i }}]
    {% end %}
  end

  # Returns `true` if this tuple has the same size as the other tuple
  # and their elements are equal to each other when compared with `==`.
  #
  # ```
  # t1 = {1, "hello"}
  # t2 = {1.0, "hello"}
  # t3 = {2, "hello"}
  #
  # t1 == t2 # => true
  # t1 == t3 # => false
  # ```
  def ==(other : self)
    {% for i in 0...T.size %}
      return false unless self[{{ i }}] == other[{{ i }}]
    {% end %}
    true
  end

  # :ditto:
  def ==(other : Tuple)
    return false unless size == other.size

    size.times do |i|
      return false unless self[i] == other[i]
    end
    true
  end

  def ==(other)
    false
  end

  # Returns `true` if case equality holds for the elements in `self` and *other*.
  #
  # ```
  # {1, 2} === {1, 2} # => true
  # {1, 2} === {1, 3} # => false
  # ```
  #
  # See also: `Object#===`.
  def ===(other : self)
    {% for i in 0...T.size %}
      return false unless self[{{ i }}] === other[{{ i }}]
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
  # See also: `Object#===`.
  def ===(other : Tuple)
    return false unless size == other.size

    size.times do |i|
      return false unless self[i] === other[i]
    end
    true
  end

  # The comparison operator.
  #
  # Each object in each tuple is compared using the `<=>` operator.
  #
  # Tuples are compared in an "element-wise" manner; the first element of this tuple is
  # compared with the first one of *other* using the `<=>` operator, then each of the second elements,
  # etc. As soon as the result of any such comparison is non-zero
  # (i.e. the two corresponding elements are not equal), that result is returned for the whole tuple comparison.
  #
  # If all the elements are equal, then the result is based on a comparison of the tuple sizes.
  # Thus, two tuples are "equal" according to `<=>` if, and only if, they have the same size
  # and the value of each element is equal to the value of the corresponding element in the other tuple.
  #
  # ```
  # {"a", "a", "c"} <=> {"a", "b", "c"} # => -1
  # {1, 2, 3, 4, 5, 6} <=> {1, 2}       # => 1
  # {1, 2} <=> {1, 2.0}                 # => 0
  # ```
  def <=>(other : self)
    {% for i in 0...T.size %}
      cmp = self[{{ i }}] <=> other[{{ i }}]
      return cmp unless cmp == 0
    {% end %}
    0
  end

  # :ditto:
  def <=>(other : Tuple)
    min_size = Math.min(size, other.size)
    min_size.times do |i|
      cmp = self[i] <=> other[i]
      return cmp unless cmp == 0
    end
    size <=> other.size
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    {% for i in 0...T.size %}
      hasher = self[{{ i }}].hash(hasher)
    {% end %}
    hasher
  end

  # Returns a tuple containing cloned elements of this tuple using the `clone` method.
  def clone
    {% begin %}
      Tuple.new(
        {% for i in 0...T.size %}
          self[{{ i }}].clone,
        {% end %}
      )
    {% end %}
  end

  # Returns a tuple that contains `self`'s elements followed by *other*'s elements.
  #
  # ```
  # t1 = {1, 2}
  # t2 = {"foo", "bar"}
  # t3 = t1 + t2
  # t3         # => {1, 2, "foo", "bar"}
  # typeof(t3) # => Tuple(Int32, Int32, String, String)
  # ```
  def +(other : Tuple)
    plus_implementation(other)
  end

  private def plus_implementation(other : U) forall U
    {% begin %}
      Tuple.new(
        {% for i in 0...@type.size %}
          self[{{ i }}],
        {% end %}
        {% for i in 0...U.size %}
          other[{{ i }}],
        {% end %}
      )
    {% end %}
  end

  # Returns the number of elements in this tuple.
  #
  # ```
  # {'a', 'b'}.size # => 2
  # ```
  def size
    {{ T.size }}
  end

  # Returns the types of this tuple type.
  #
  # ```
  # tuple = {1, "hello", 'x'}
  # tuple.class.types # => {Int32, String, Char}
  # ```
  def self.types
    Tuple.new(*{{ T }})
  end

  # Same as `to_s`.
  def inspect : String
    to_s
  end

  # Returns an `Array` with all the elements in the tuple.
  #
  # ```
  # {1, 2, 3, 4, 5}.to_a # => [1, 2, 3, 4, 5]
  # ```
  def to_a : Array(Union(*T))
    super
  end

  # Returns an `Array` with the results of running *block* against each element of the tuple.
  #
  # ```
  # {1, 2, 3, 4, 5}).to_a { |i| i * 2 } # => [2, 4, 6, 8, 10]
  # ```
  def to_a(& : Union(*T) -> U) forall U
    Array(U).build(size) do |buffer|
      {% for i in 0...T.size %}
        buffer[{{ i }}] = yield self[{{ i }}]
      {% end %}
      size
    end
  end

  # Returns a `StaticArray` with the same elements.
  #
  # The element type is `Union(*T)`.
  #
  # ```
  # {1, 'a', true}.to_static_array # => StaticArray[1, 'a', true]
  # ```
  @[AlwaysInline]
  def to_static_array : StaticArray
    {% begin %}
      ary = uninitialized StaticArray(Union(*T), {{ T.size }})
      each_with_index do |value, i|
        ary.to_unsafe[i] = value
      end
      ary
    {% end %}
  end

  # Appends a string representation of this tuple to the given `IO`.
  #
  # ```
  # tuple = {1, "hello"}
  # tuple.to_s # => "{1, \"hello\"}"
  # ```
  def to_s(io : IO) : Nil
    needs_padding = curly_like?(self.first?)

    io << '{'
    io << ' ' if needs_padding

    join io, ", ", &.inspect(io)

    io << ' ' if needs_padding
    io << '}'
  end

  private def curly_like?(object)
    case object
    when Hash, Tuple, NamedTuple
      true
    else
      false
    end
  end

  def pretty_print(pp) : Nil
    pp.list("{", self, "}")
  end

  # Returns a new tuple where elements are mapped by the given block.
  #
  # ```
  # tuple = {1, 2.5, "a"}
  # tuple.map &.to_s # => {"1", "2.5", "a"}
  # ```
  def map(& : Union(*T) ->)
    {% begin %}
      Tuple.new(
        {% for i in 0...T.size %}
          (yield self[{{ i }}]),
        {% end %}
      )
   {% end %}
  end

  # Like `map`, but the block gets passed both the element and its index.
  #
  # ```
  # tuple = {1, 2.5, "a"}
  # tuple.map_with_index { |e, i| "tuple[#{i}]: #{e}" } # => {"tuple[0]: 1", "tuple[1]: 2.5", "tuple[2]: a"}
  # ```
  #
  # Accepts an optional *offset* parameter, which tells it to start counting
  # from there.
  def map_with_index(offset = 0, &)
    {% begin %}
      Tuple.new(
        {% for i in 0...T.size %}
          (yield self[{{ i }}], offset + {{ i }}),
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
    {% begin %}
      Tuple.new(
        {% for i in 1..T.size %}
          self[{{ T.size - i }}],
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
  def reverse_each(& : Union(*T) ->)
    {% for i in 1..T.size %}
      yield self[{{ T.size - i }}]
    {% end %}
    nil
  end

  # :inherit:
  def reduce(&)
    {% if T.empty? %}
      raise Enumerable::EmptyError.new
    {% else %}
      memo = self[0]
      {% for i in 1...T.size %}
        memo = yield memo, self[{{ i }}]
      {% end %}
      memo
    {% end %}
  end

  # :inherit:
  def reduce(memo, &)
    {% for i in 0...T.size %}
      memo = yield memo, self[{{ i }}]
    {% end %}
    memo
  end

  # :inherit:
  def reduce?(&)
    {% unless T.empty? %}
      reduce { |memo, elem| yield memo, elem }
    {% end %}
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

  # Returns the first element of this tuple, or `nil` if this
  # is the empty tuple.
  #
  # ```
  # tuple = {1, 2.5}
  # tuple.first? # => 1
  #
  # empty = Tuple.new
  # empty.first? # => nil
  # ```
  def first?
    {% if T.size == 0 %}
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
    {% begin %}
      self[{{ T.size - 1 }}]
    {% end %}
  end

  # Returns the last element of this tuple, or `nil` if this
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
    {% if T.size == 0 %}
      nil
    {% else %}
      self[{{ T.size - 1 }}]
    {% end %}
  end

  # Returns a value with the same type as the element at the given *index* of
  # an instance of `self`. *index* must be an integer or range literal known at
  # compile-time.
  #
  # The most common usage of this macro is to extract the appropriate element
  # type in `Tuple`'s class methods. This macro works even if the corresponding
  # element type is private.
  #
  # NOTE: there should never be a need to call this method outside the standard library.
  private macro element_type(index)
    x = uninitialized self
    x[{{ index }}]
  end
end
