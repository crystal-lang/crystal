# Struct is the base type of structs you create in your program.
# It is set as a struct's superstruct when you don't specify one:
#
# ```
# struct Foo # < Struct
# end
# ```
#
# Structs inherit from `Value` so they are allocated on the stack and passed
# by value. For this reason you should prefer using structs for immutable
# data types and/or stateless wrappers of other types.
#
# Mutable structs are still allowed, but code involving them must remember
# that passing a struct to a method actually passes a copy to it, so the
# method should return the modified struct:
#
# ```
# struct Mutable
#   property value
#
#   def initialize(@value)
#   end
# end
#
# def change_bad(mutable)
#   mutable.value = 2
# end
#
# def change_good(mutable)
#   mutable.value = 2
#   mutable
# end
#
# mut = Mutable.new 1
# change_bad(mut)
# mut.value # => 1
#
# mut = change_good(mut)
# mut.value # => 2
# ```
#
# The standard library provides a useful `record` macro that allows you to
# create immutable structs with some fields, similar to a `Tuple` but using
# names instead of indices.
struct Struct
  # Returns `true` if this struct is equal to `other`.
  #
  # Both structs's instance vars are compared to each other. Thus, two
  # structs are considered equal if each of their instance variables are
  # equal. Subclasses should override this method to provide specific
  # equality semantics.
  #
  # ```
  # struct Point
  #   def initialize(@x, @y)
  #   end
  # end
  #
  # p1 = Point.new 1, 2
  # p2 = Point.new 1, 2
  # p3 = Point.new 3, 4
  #
  # p1 == p2 # => true
  # p1 == p3 # => false
  # ```
  def ==(other : self) : Bool
    {% for ivar in @type.instance_vars %}
      return false unless @{{ivar.id}} == other.@{{ivar.id}}
    {% end %}
    true
  end

  # Returns a hash value based on this struct's instance variables hash values.
  #
  # See `Object#hash`
  def hash : Int32
    hash = 0
    {% for ivar in @type.instance_vars %}
      hash = 31 * hash + @{{ivar.id}}.hash.to_i32
    {% end %}
    hash
  end

  # Appends this struct's name and instance variables names and values
  # to the given IO.
  #
  # ```
  # struct Point
  #   def initialize(@x, @y)
  #   end
  # end
  #
  # p1 = Point.new 1, 2
  # p1.to_s    # "Point(@x=1, @y=2)"
  # p1.inspect # "Point(@x=1, @y=2)"
  # ```
  def inspect(io : IO) : Nil
    io << {{@type.name.id.stringify}} << "("
    {% for ivar, i in @type.instance_vars %}
      {% if i > 0 %}
        io << ", "
      {% end %}
      io << "@{{ivar.id}}="
      @{{ivar.id}}.inspect(io)
    {% end %}
    io << ")"
    nil
  end

  def pretty_print(pp) : Nil
    prefix = "#{{{@type.name.id.stringify}}}("
    pp.surround(prefix, ")", left_break: "", right_break: nil) do
      {% for ivar, i in @type.instance_vars.map(&.name).sort %}
        {% if i > 0 %}
          pp.comma
        {% end %}
        pp.group do
          pp.text "@{{ivar.id}}="
          pp.nest do
            pp.breakable ""
            @{{ivar.id}}.pretty_print(pp)
          end
        end
      {% end %}
    end
  end

  # Same as `#inspect(io)`.
  def to_s(io)
    inspect(io)
  end
end
