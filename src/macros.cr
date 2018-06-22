# Defines a **`Struct`** with the given name and properties.
#
# The generated struct has a constructor with the given properties
# in the same order as declared. The struct only provides getters,
# not setters, making it immutable by default.
#
# The properties can be type declarations or assignments.
#
# You can pass a block to this macro, that will be inserted inside
# the struct definition.
#
# ```
# record Point, x : Int32, y : Int32
#
# Point.new 1, 2 # => #<Point(@x=1, @y=2)>
# ```
#
# An example with the block version:
#
# ```
# record Person, first_name : String, last_name : String do
#   def full_name
#     "#{first_name} #{last_name}"
#   end
# end
#
# person = Person.new "John", "Doe"
# person.full_name # => "John Doe"
# ```
#
# An example with type declarations and default values:
#
# ```
# record Point, x : Int32 = 0, y : Int32 = 0
#
# Point.new      # => #<Point(@x=0, @y=0)>
# Point.new y: 2 # => #<Point(@x=0, @y=2)>
# ```
#
# An example with assignments (in this case the compiler must be able to
# infer the types from the default values):
#
# ```
# record Point, x = 0, y = 0
#
# Point.new      # => #<Point(@x=0, @y=0)>
# Point.new y: 2 # => #<Point(@x=0, @y=2)>
# ```
#
# This macro also provides a `copy_with` method which returns
# a copy of the record with the provided properties altered.
#
# ```
# record Point, x = 0, y = 0
#
# p = Point.new y: 2 # => #<Point(@x=0, @y=2)>
# p.copy_with x: 3   # => #<Point(@x=3, @y=2)>
# p                  # => #<Point(@x=0, @y=2)>
# ```
macro record(name, *properties)
  struct {{name.id}}
    {% for property in properties %}
      {% if property.is_a?(Assign) %}
        getter {{property.target.id}}
      {% elsif property.is_a?(TypeDeclaration) %}
        getter {{property.var}} : {{property.type}}
      {% else %}
        getter :{{property.id}}
      {% end %}
    {% end %}

    def initialize({{
                     *properties.map do |field|
                       "@#{field.id}".id
                     end
                   }})
    end

    {{yield}}

    def copy_with({{
                    *properties.map do |property|
                      if property.is_a?(Assign)
                        "#{property.target.id} _#{property.target.id} = @#{property.target.id}".id
                      elsif property.is_a?(TypeDeclaration)
                        "#{property.var.id} _#{property.var.id} = @#{property.var.id}".id
                      else
                        "#{property.id} _#{property.id} = @#{property.id}".id
                      end
                    end
                  }})
      {{name.id}}.new({{
                        *properties.map do |property|
                          if property.is_a?(Assign)
                            "_#{property.target.id}".id
                          elsif property.is_a?(TypeDeclaration)
                            "_#{property.var.id}".id
                          else
                            "_#{property.id}".id
                          end
                        end
                      }})
    end

    def clone
      {{name.id}}.new({{
                        *properties.map do |property|
                          if property.is_a?(Assign)
                            "@#{property.target.id}.clone".id
                          elsif property.is_a?(TypeDeclaration)
                            "@#{property.var.id}.clone".id
                          else
                            "@#{property.id}.clone".id
                          end
                        end
                      }})
    end
  end
end

# Prints a series of expressions together with their pretty printed values.
# Useful for print style debugging.
#
# ```
# a = 1
# pp! a # => "a # => 1"
#
# pp! [1, 2, 3].map(&.to_s) # => "[1, 2, 3].map(&.to_s) # => ["1", "2", "3"]"
# ```
#
# See also: `pp`, `Object#pretty_inspect`.
macro pp!(*exps)
  {% if exps.size == 0 %}
    # Nothing
  {% elsif exps.size == 1 %}
    {% exp = exps.first %}
    %prefix = "#{{{ exp.stringify }}} # => "
    ::print %prefix
    ::pp {{exp}}
  {% else %}
    %names = { {{*exps.map(&.stringify)}} }
    %max_size = %names.max_of &.size
    {
      {% for exp, i in exps %}
        begin
          %prefix = "#{%names[{{i}}].ljust(%max_size)} # => "
          ::print %prefix
          ::pp {{exp}}
        end,
      {% end %}
    }
  {% end %}
end

# Prints a series of expressions together with their inspected values.
# Useful for print style debugging.
#
# ```
# a = 1
# p! a # => "a # => 1"
#
# p! [1, 2, 3].map(&.to_s) # => "[1, 2, 3].map(&.to_s) # => ["1", "2", "3"]"
# ```
#
# See also: `p`, `Object#inspect`.
macro p!(*exps)
  {% if exps.size == 0 %}
    # Nothing
  {% elsif exps.size == 1 %}
    {% exp = exps.first %}
    %prefix = "#{{{ exp.stringify }}} # => "
    ::print %prefix
    ::p {{exp}}
  {% else %}
    %names = { {{*exps.map(&.stringify)}} }
    %max_size = %names.max_of &.size
    {
      {% for exp, i in exps %}
        begin
          %prefix = "#{%names[{{i}}].ljust(%max_size)} # => "
          ::print %prefix
          ::p {{exp}}
        end,
      {% end %}
    }
  {% end %}
end

macro assert_responds_to(var, method)
  if {{var}}.responds_to?(:{{method}})
    {{var}}
  else
    raise "Expected {{var}} to respond to :{{method}}, not #{ {{var}} }"
  end
end
