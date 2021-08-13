# Enum is the base type of all enums.
#
# An enum is a set of integer values, where each value has an associated name. For example:
#
# ```
# enum Color
#   Red   # 0
#   Green # 1
#   Blue  # 2
# end
# ```
#
# Values start with the value `0` and are incremented by one, but can be overwritten.
#
# To get the underlying value you invoke value on it:
#
# ```
# Color::Green.value # => 1
# ```
#
# Each constant (member) in the enum has the type of the enum:
#
# ```
# typeof(Color::Red) # => Color
# ```
#
# ### Flags enum
#
# An enum can be marked with the `@[Flags]` annotation. This changes the default values:
#
# ```
# @[Flags]
# enum IOMode
#   Read  # 1
#   Write # 2
#   Async # 4
# end
# ```
#
# Additionally, some methods change their behaviour.
#
# ### Enums from integers
#
# An enum can be created from an integer:
#
# ```
# Color.new(1).to_s # => "Green"
# ```
#
# Values that don't correspond to enum's constants are allowed: the value
# will still be of type Color, but when printed you will get the underlying value:
#
# ```
# Color.new(10).to_s # => "10"
# ```
#
# This method is mainly intended to convert integers from C to enums in Crystal.
#
# ### Question methods
#
# An enum automatically defines question methods for each member, using
# `String#underscore` for the method name.
# * In the case of regular enums, this compares by equality (`==`).
# * In the case of flags enums, this invokes `includes?`.
#
# For example:
#
# ```
# color = Color::Blue
# color.red?  # => false
# color.blue? # => true
#
# mode = IOMode::Read | IOMode::Async
# mode.read?  # => true
# mode.write? # => false
# mode.async? # => true
# ```
#
# This is very convenient in `case` expressions:
#
# ```
# case color
# when .red?
#   puts "Got red"
# when .blue?
#   puts "Got blue"
# end
# ```
struct Enum
  include Comparable(self)

  # Returns *value*.
  def self.new(value : self)
    value
  end

  # Appends a `String` representation of this enum member to the given *io*.
  #
  # See also: `to_s`.
  def to_s(io : IO) : Nil
    {% if @type.annotation(Flags) %}
      if value == 0
        io << "None"
      else
        found = false
        {% for member in @type.constants %}
          {% if member.stringify != "All" %}
            if {{@type.constant(member)}} != 0 && value.bits_set? {{@type.constant(member)}}
              io << " | " if found
              io << {{member.stringify}}
              found = true
            end
          {% end %}
        {% end %}
        io << value unless found
      end
    {% else %}
      io << to_s
    {% end %}
    nil
  end

  # Returns a `String` representation of this enum member.
  # In the case of regular enums, this is just the name of the member.
  # In the case of flag enums, it's the names joined by vertical bars, or "None",
  # if the value is zero.
  #
  # If an enum's value doesn't match a member's value, the raw value
  # is returned as a string.
  #
  # ```
  # Color::Red.to_s                     # => "Red"
  # IOMode::None.to_s                   # => "None"
  # (IOMode::Read | IOMode::Write).to_s # => "Read | Write"
  #
  # Color.new(10).to_s # => "10"
  # ```
  def to_s : String
    {% if @type.annotation(Flags) %}
      String.build { |io| to_s(io) }
    {% else %}
      # Can't use `case` here because case with duplicate values do
      # not compile, but enums can have duplicates (such as `enum Foo; FOO = 1; BAR = 1; end`).
      {% for member, i in @type.constants %}
        if value == {{@type.constant(member)}}
          return {{member.stringify}}
        end
      {% end %}

      value.to_s
    {% end %}
  end

  # Returns the value of this enum member as an `Int32`.
  #
  # ```
  # Color::Blue.to_i                    # => 2
  # (IOMode::Read | IOMode::Write).to_i # => 3
  #
  # Color.new(10).to_i # => 10
  # ```
  def to_i : Int32
    value.to_i32
  end

  {% for name in %w(i8 i16 i32 i64 u8 u16 u32 u64 f32 f64) %}
    {% prefix = name.starts_with?('i') ? "Int".id : (name.starts_with?('u') ? "UInt".id : "Float".id) %}
    {% type = "#{prefix}#{name[1..-1].id}".id %}
    # Returns the value of this enum member as a `{{type}}`
    def to_{{name.id}} : {{type}}
      value.to_{{name.id}}
    end

    # Returns the value of this enum member as a `{{type}}`
    def to_{{name.id}}! : {{type}}
      value.to_{{name.id}}!
    end
  {% end %}

  # Returns the enum member that results from adding *other*
  # to this enum member's value.
  #
  # ```
  # Color::Red + 1 # => Color::Green
  # Color::Red + 2 # => Color::Blue
  # Color::Red + 3 # => Color.new(3)
  # ```
  def +(other : Int) : self
    self.class.new(value + other)
  end

  # Returns the enum member that results from subtracting *other*
  # to this enum member's value.
  #
  # ```
  # Color::Blue - 1 # => Color::Green
  # Color::Blue - 2 # => Color::Red
  # Color::Blue - 3 # => Color.new(-1)
  # ```
  def -(other : Int) : self
    self.class.new(value - other)
  end

  # Returns the enum member that results from applying a logical
  # "or" operation between this enum member's value and *other*.
  # This is mostly useful with flag enums.
  #
  # ```
  # (IOMode::Read | IOMode::Async) # => IOMode::Read | IOMode::Async
  # ```
  def |(other : self) : self
    self.class.new(value | other.value)
  end

  # Returns the enum member that results from applying a logical
  # "and" operation between this enum member's value and *other*.
  # This is mostly useful with flag enums.
  #
  # ```
  # (IOMode::Read | IOMode::Async) & IOMode::Read # => IOMode::Read
  # ```
  def &(other : self) : self
    self.class.new(value & other.value)
  end

  # Returns the enum member that results from applying a logical
  # "xor" operation between this enum member's value and *other*.
  # This is mostly useful with flag enums.
  def ^(other : self) : self
    self.class.new(value ^ other.value)
  end

  # Returns the enum member that results from applying a logical
  # "not" operation of this enum member's value.
  def ~ : self
    self.class.new(~value)
  end

  # Compares this enum member against another, according to their underlying
  # value.
  #
  # ```
  # Color::Red <=> Color::Blue  # => -1
  # Color::Blue <=> Color::Red  # => 1
  # Color::Blue <=> Color::Blue # => 0
  # ```
  def <=>(other : self)
    value <=> other.value
  end

  # :nodoc:
  def ==(other)
    false
  end

  # Returns `true` if this enum member's value includes *other*. This
  # performs a logical "and" between this enum member's value and *other*'s,
  # so instead of writing:
  #
  # ```
  # (member & value) != 0
  # ```
  #
  # you can write:
  #
  # ```
  # member.includes?(value)
  # ```
  #
  # The above is mostly useful with flag enums.
  #
  # For example:
  #
  # ```
  # mode = IOMode::Read | IOMode::Write
  # mode.includes?(IOMode::Read)  # => true
  # mode.includes?(IOMode::Async) # => false
  # ```
  def includes?(other : self) : Bool
    (value & other.value) != 0
  end

  # Returns `true` if this enum member and *other* have the same underlying value.
  #
  # ```
  # Color::Red == Color::Red  # => true
  # Color::Red == Color::Blue # => false
  # ```
  def ==(other : self)
    value == other.value
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.enum(self)
  end

  # Iterates each values in a Flags Enum.
  #
  # ```
  # (IOMode::Read | IOMode::Async).each do |member, value|
  #   # yield IOMode::Read, 1
  #   # yield IOMode::Async, 3
  # end
  # ```
  def each
    {% if @type.annotation(Flags) %}
      return if value == 0
      {% for member in @type.constants %}
        {% if member.stringify != "All" %}
          if includes?(self.class.new({{@type.constant(member)}}))
            yield self.class.new({{@type.constant(member)}}), {{@type.constant(member)}}
          end
        {% end %}
      {% end %}
    {% else %}
      {% raise "Can't iterate #{@type}: only Flags Enum can be iterated" %}
    {% end %}
  end

  # Returns all enum members as an `Array(String)`.
  #
  # ```
  # Color.names # => ["Red", "Green", "Blue"]
  # ```
  def self.names : Array(String)
    {% if @type.annotation(Flags) %}
      {{ @type.constants.select { |e| e.stringify != "None" && e.stringify != "All" }.map &.stringify }}
    {% else %}
      {{ @type.constants.map &.stringify }}
    {% end %}
  end

  # Returns all enum members as an `Array(self)`.
  #
  # ```
  # Color.values # => [Color::Red, Color::Green, Color::Blue]
  # ```
  def self.values : Array(self)
    {% if @type.annotation(Flags) %}
      {{ @type.constants.select { |e| e.stringify != "None" && e.stringify != "All" }.map { |e| "#{@type}::#{e.id}".id } }}
    {% else %}
      {{ @type.constants.map { |e| "#{@type}::#{e.id}".id } }}
    {% end %}
  end

  # Returns the enum member that has the given value, or `nil` if
  # no such member exists.
  #
  # ```
  # Color.from_value?(0) # => Color::Red
  # Color.from_value?(1) # => Color::Green
  # Color.from_value?(2) # => Color::Blue
  # Color.from_value?(3) # => nil
  # ```
  def self.from_value?(value : Int) : self?
    {% if @type.annotation(Flags) %}
      all_mask = {{@type}}::All.value
      return if all_mask & value != value
      return new(all_mask.class.new(value))
    {% else %}
      {% for member in @type.constants %}
        return new({{@type.constant(member)}}) if {{@type.constant(member)}} == value
      {% end %}
    {% end %}
    nil
  end

  # Returns the enum member that has the given value, or raises
  # if no such member exists.
  #
  # ```
  # Color.from_value(0) # => Color::Red
  # Color.from_value(1) # => Color::Green
  # Color.from_value(2) # => Color::Blue
  # Color.from_value(3) # raises Exception
  # ```
  def self.from_value(value : Int) : self
    from_value?(value) || raise "Unknown enum #{self} value: #{value}"
  end

  # Returns `true` if the given *value* is an enum member, otherwise `false`.
  # `false` if not member.
  #
  # ```
  # Color.valid?(Color::Red)   # => true
  # Color.valid?(Color.new(4)) # => false
  # ```
  #
  # NOTE: This is a class method, not an instance method because
  # an instance method `valid?` is defined by the language when a user
  # defines an enum member named `Valid`.
  def self.valid?(value : self) : Bool
    !!from_value?(value.value)
  end

  # def self.to_h : Hash(String, self)
  #   {
  #     {% for member in @type.constants %}
  #       {{member.stringify}} => {{member}},
  #     {% end %}
  #   }
  # end

  # Returns the enum member that has the given name, or
  # raises `ArgumentError` if no such member exists. The comparison is made by using
  # `String#camelcase` and `String#downcase` between *string* and
  # the enum members names, so a member named "FortyTwo" or "FORTY_TWO"
  # is found with any of these strings: "forty_two", "FortyTwo", "FORTY_TWO",
  # "FORTYTWO", "fortytwo".
  #
  # ```
  # Color.parse("Red")    # => Color::Red
  # Color.parse("BLUE")   # => Color::Blue
  # Color.parse("Yellow") # raises ArgumentError
  # ```
  def self.parse(string : String) : self
    parse?(string) || raise ArgumentError.new("Unknown enum #{self} value: #{string}")
  end

  # Returns the enum member that has the given name, or
  # `nil` if no such member exists. The comparison is made by using
  # `String#camelcase` and `String#downcase` between *string* and
  # the enum members names, so a member named "FortyTwo" or "FORTY_TWO"
  # is found with any of these strings: "forty_two", "FortyTwo", "FORTY_TWO",
  # "FORTYTWO", "fortytwo".
  #
  # ```
  # Color.parse?("Red")    # => Color::Red
  # Color.parse?("BLUE")   # => Color::Blue
  # Color.parse?("Yellow") # => nil
  # ```
  def self.parse?(string : String) : self?
    {% begin %}
      case string.camelcase.downcase
      {% for member in @type.constants %}
        when {{member.stringify.camelcase.downcase}}
          new({{@type.constant(member)}})
      {% end %}
      else
        nil
      end
    {% end %}
  end

  def clone
    self
  end

  # Convenience macro to create a combined enum (combines given members using `|` (or) logical operator)
  #
  # ```
  # IOMode.flags(Read, Write) # => IOMode::Read | IOMode::Write
  # ```
  macro flags(*values)
    {% for value, i in values %}\
      {% if i != 0 %} | {% end %}\
      {{ @type }}::{{ value }}{% end %}\
  end

  # Iterates each member of the enum.
  # It won't iterate the `None` and `All` members of flags enums.
  #
  # ```
  # IOMode.each do |member, value|
  #   # yield IOMode::Read, 1
  #   # yield IOMode::Write, 2
  #   # yield IOMode::Async, 3
  # end
  # ```
  def self.each
    {% for member in @type.constants %}
      {% unless @type.annotation(Flags) && %w(none all).includes?(member.stringify.downcase) %}
        yield new({{@type.constant(member)}}), {{@type.constant(member)}}
      {% end %}
    {% end %}
  end
end
