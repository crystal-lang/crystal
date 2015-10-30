# Defines a **struct** with the given name and properties.
#
# The generated struct has a constructor with the given properties
# in the same order as declared. The struct only provides getters,
# not setters, making it immutable by default.
#
# You can pass a block to this macro, that will be inserted inside
# the struct definition.
#
# ```
# record Point, x, y
#
# point = Point.new 1, 2
# point.to_s # => "Point(@x=1, @y=2)"
# ```
#
# An example with the block version:
#
# ```
# record Person, first_name, last_name do
#   def full_name
#     "#{first_name} #{last_name}"
#   end
# end
#
# person = Person.new "John", "Doe"
# person.full_name # => "John Doe"
# ```
macro record(name, *properties)
  struct {{name.id}}
    getter {{*properties}}

    def initialize({{ *properties.map { |field| "@#{field.id}".id } }})
    end

    {{yield}}

    def clone
      {{name.id}}.new({{ *properties.map { |field| "@#{field.id}.clone".id } }})
    end
  end
end

# Prints a series of expressions together with their values. Useful for print style debugging.
#
# ```
# a = 1
# pp a # prints "a = 1"
#
# pp [1, 2, 3].map(&.to_s) # prints "[1, 2, 3].map(&.to_s) = ["1", "2", "3"]
# ```
macro pp(*exps)
  {% for exp in exps %}
    ::puts "#{ {{exp.stringify}} } = #{ ({{exp}}).inspect }"
  {% end %}
end

macro assert_responds_to(var, method)
  if {{var}}.responds_to?(:{{method}})
    {{var}}
  else
    raise "expected {{var}} to respond to :{{method}}, not #{ {{var}} }"
  end
end
