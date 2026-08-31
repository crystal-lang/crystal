# `Struct` is the base type of structs you create in your program.
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
#   def initialize(@value : Int32)
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
  # Returns `true` if this struct is equal to *other*.
  #
  # Both structs' instance vars are compared to each other. Thus, two
  # structs are considered equal if each of their instance variables are
  # equal. Subclasses should override this method to provide specific
  # equality semantics.
  #
  # ```
  # struct Point
  #   def initialize(@x : Int32, @y : Int32)
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
  def ==(other) : Bool
    # TODO: This is a workaround for https://github.com/crystal-lang/crystal/issues/5249
    if other.is_a?(self)
      {% for ivar in @type.instance_vars %}
        return false unless @{{ ivar.id }} == other.@{{ ivar.id }}
      {% end %}
      true
    else
      false
    end
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    {% for ivar in @type.instance_vars %}
      hasher = @{{ ivar.id }}.hash(hasher)
    {% end %}
    hasher
  end

  # Appends this struct's name and instance variables names and values
  # to the given IO.
  #
  # ```
  # struct Point
  #   def initialize(@x : Int32, @y : Int32)
  #   end
  # end
  #
  # p1 = Point.new 1, 2
  # p1.to_s    # "Point(@x=1, @y=2)"
  # p1.inspect # "Point(@x=1, @y=2)"
  # ```
  def inspect(io : IO) : Nil
    io << {{ @type.name.id.stringify }} << '('
    {% for ivar, i in @type.instance_vars %}
      {% if i > 0 %}
        io << ", "
      {% end %}
      io << "@{{ ivar.id }}="
      @{{ ivar.id }}.inspect(io)
    {% end %}
    io << ')'
  end

  def pretty_print(pp) : Nil
    {% if @type.overrides?(Struct, "inspect") %}
      pp.text inspect
    {% else %}
      prefix = "#{{{ @type.name.id.stringify }}}("
      pp.surround(prefix, ")", left_break: "", right_break: nil) do
        {% for ivar, i in @type.instance_vars.map(&.name).sort %}
          {% if i > 0 %}
            pp.comma
          {% end %}
          pp.group do
            pp.text "@{{ ivar.id }}="
            pp.nest do
              pp.breakable ""
              @{{ ivar.id }}.pretty_print(pp)
            end
          end
        {% end %}
      end
    {% end %}
  end

  # Same as `#inspect(io)`.
  def to_s(io : IO) : Nil
    inspect(io)
  end
end
