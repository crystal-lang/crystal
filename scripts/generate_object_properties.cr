#! /usr/bin/env crystal
#
# This script generates the `src/object/properties.cr` file with the whole set
# of `[class_](getter|setter|property)[?!]` macros to avoid duplicating the
# implementations. Having an external script avoids the runtime cost of having
# macros generating AST calls to other macros that must expanded again.

struct Generator
  def initialize(@file : File, @macro_prefix : String, @method_prefix : String, @var_prefix : String, @doc_prefix : String)
  end

  def puts
    @file.puts
  end

  def puts(message)
    @file.puts(message)
  end

  def def_vars
    def_vars do
      <<-TEXT
              {% if block %}
                #{@var_prefix}{{var_name}} : {{type}}? {% if name.value %} = {{name.value}} {% end %}
              {% else %}
                #{@var_prefix}{{name}}
              {% end %}
      TEXT
    end
  end

  def def_vars_no_macro_block
    def_vars { "#{@var_prefix}{{name}}" }
  end

  def def_vars(&)
    <<-TEXT
          {% if name.is_a?(TypeDeclaration) %}
            {% var_name = name.var.id %}
            {% type = name.type %}
            #{yield.lstrip}
          {% elsif name.is_a?(Assign) %}
            {% var_name = name.target %}
            {% type = nil %}
            #{@var_prefix}{{name}}
          {% else %}
            {% var_name = name.id %}
            {% type = nil %}
          {% end %}

    TEXT
  end

  def def_vars!
    <<-TEXT
          {% if name.is_a?(TypeDeclaration) %}
            {% var_name = name.var.id %}
            {% type = name.type %}
            #{@var_prefix}{{name}}?
          {% else %}
            {% var_name = name.id %}
            {% type = nil %}
          {% end %}

    TEXT
  end

  def def_getter(suffix = "")
    <<-TEXT
          def #{@method_prefix}{{var_name}}#{suffix} {% if type %} : {{type}} {% end %}
            {% if block %}
              if (%value = #{@var_prefix}{{var_name}}).nil?
                #{@var_prefix}{{var_name}} = {{yield}}
              else
                %value
              end
            {% else %}
              #{@var_prefix}{{var_name}}
            {% end %}
          end

    TEXT
  end

  def def_getter!
    <<-TEXT
          def #{@method_prefix}{{var_name}}? {% if type %} : {{type}}? {% end %}
            #{@var_prefix}{{var_name}}
          end

          def #{@method_prefix}{{var_name}} {% if type %} : {{type}} {% end %}
            if (%value = #{@var_prefix}{{var_name}}).nil?
              ::raise ::NilAssertionError.new("{{@type.id}}{{#{@doc_prefix.inspect}.id}}{{var_name}} cannot be nil")
            else
              %value
            end
          end

    TEXT
  end

  def def_setter
    <<-TEXT
          def #{@method_prefix}{{var_name}}=(#{@var_prefix}{{var_name}}{% if type %} : {{type}} {% end %})
          end

    TEXT
  end

  def gen_getter
    puts <<-TEXT
      macro #{@macro_prefix}getter(*names, &block)
        {% for name in names %}
    #{def_vars}
    #{def_getter}
        {% end %}
      end
    TEXT
  end

  def gen_getter?
    puts <<-TEXT
      macro #{@macro_prefix}getter?(*names, &block)
        {% for name in names %}
    #{def_vars}
    #{def_getter "?"}
        {% end %}
      end
    TEXT
  end

  def gen_property
    puts <<-TEXT
      # Generates both `#{@macro_prefix}getter` and `#{@macro_prefix}setter`
      # methods to access instance variables.
      #
      # Refer to the aforementioned macros for details.
      macro #{@macro_prefix}property(*names, &block)
        {% for name in names %}
    #{def_vars}
    #{def_getter}
    #{def_setter}
        {% end %}
      end
    TEXT
  end

  def gen_property?
    puts <<-TEXT
      # Generates both `#{@macro_prefix}getter?` and `#{@macro_prefix}setter`
      # methods to access instance variables.
      #
      # Refer to the aforementioned macros for details.
      macro #{@macro_prefix}property?(*names, &block)
        {% for name in names %}
    #{def_vars}
    #{def_getter "?"}
    #{def_setter}
        {% end %}
      end
    TEXT
  end

  def gen_getter!
    puts <<-TEXT
      macro #{@macro_prefix}getter!(*names)
        {% for name in names %}
    #{def_vars!}
    #{def_getter!}
        {% end %}
      end
    TEXT
  end

  def gen_property!
    puts <<-TEXT
      # Generates both `#{@macro_prefix}getter!` and `#{@macro_prefix}setter`
      # methods to access instance variables.
      #
      # Refer to the aforementioned macros for details.
      macro #{@macro_prefix}property!(*names)
        {% for name in names %}
    #{def_vars!}
    #{def_getter!}
    #{def_setter}
        {% end %}
      end
    TEXT
  end

  def gen_setter
    puts <<-TEXT
      macro #{@macro_prefix}setter(*names)
        {% for name in names %}
    #{def_vars_no_macro_block}
    #{def_setter}
        {% end %}
      end
    TEXT
  end
end

directory = File.expand_path("../src/object", __DIR__)
Dir.mkdir(directory) unless Dir.exists?(directory)

output = File.join(directory, "properties.cr")
File.open(output, "w") do |f|
  f.puts "# This file was automatically generated by running:"
  f.puts "#"
  f.puts "#   scripts/generate_object_properties.cr"
  f.puts "#"
  f.puts "# DO NOT EDIT"
  f.puts
  f.puts "class Object"

  g = Generator.new(f, "", "", "@", "#")

  f.puts <<-MARKDOWN
  # Defines getter method(s) to access instance variable(s).
  #
  # Refer to [Getters](#getters) for details.
  MARKDOWN
  g.gen_getter

  f.puts <<-MARKDOWN
  # Identical to `getter` but defines query methods.
  #
  # For example writing:
  #
  # ```
  # class Robot
  #   getter? working
  # end
  # ```
  #
  # Is equivalent to writing:
  #
  # ```
  # class Robot
  #   def working?
  #     @working
  #   end
  # end
  # ```
  #
  # Refer to [Getters](#getters) for general details.
  MARKDOWN
  g.gen_getter?

  f.puts <<-MARKDOWN
  # Similar to `getter` but defines both raise-on-nil methods as well as query
  # methods that return a nilable value.
  #
  # If a type is specified, then it will become a nilable type (union of the
  # type and `Nil`). Unlike the other `getter` methods the value is always
  # initialized to `nil`. There are no initial value or lazy initialization.
  #
  # For example writing:
  #
  # ```
  # class Robot
  #   getter! name : String
  # end
  # ```
  #
  # Is equivalent to writing:
  #
  # ```
  # class Robot
  #   @name : String?
  #
  #   def name? : String?
  #     @name
  #   end
  #
  #   def name : String
  #     @name.not_nil!("Robot#name cannot be nil")
  #   end
  # end
  # ```
  #
  # Refer to [Getters](#getters) for general details.
  MARKDOWN
  g.gen_getter!

  f.puts <<-MARKDOWN
  # Generates setter methods to set instance variables.
  #
  # Refer to [Setters](#setters) for general details.
  MARKDOWN
  g.gen_setter

  g.gen_property
  g.gen_property?
  g.gen_property!

  g = Generator.new(f, "class_", "self.", "@@", ".")

  f.puts <<-MARKDOWN
  # Defines getter method(s) to access class variable(s).
  #
  # For example writing:
  #
  # ```
  # class Robot
  #   class_getter backend
  # end
  # ```
  #
  # Is equivalent to writing:
  #
  # ```
  # class Robot
  #   @@backend : String
  #
  #   def self.backend
  #     @@backend
  #   end
  # end
  # ```
  #
  # Refer to [Getters](#getters) for details.
  MARKDOWN
  g.gen_getter

  f.puts <<-MARKDOWN
  # Identical to `class_getter` but defines query methods.
  #
  # For example writing:
  #
  # ```
  # class Robot
  #   class_getter? backend
  # end
  # ```
  #
  # Is equivalent to writing:
  #
  # ```
  # class Robot
  #   def self.backend?
  #     @@backend
  #   end
  # end
  # ```
  #
  # Refer to [Getters](#getters) for general details.
  MARKDOWN
  g.gen_getter?

  f.puts <<-MARKDOWN
  # Similar to `class_getter` but defines both raise-on-nil methods as well as
  # query methods that return a nilable value.
  #
  # If a type is specified, then it will become a nilable type (union of the
  # type and `Nil`). Unlike with `class_getter` the value is always initialized
  # to `nil`. There are no initial value or lazy initialization.
  #
  # For example writing:
  #
  # ```
  # class Robot
  #   class_getter! backend : String
  # end
  # ```
  #
  # Is equivalent to writing:
  #
  # ```
  # class Robot
  #   @@backend : String?
  #
  #   def self.backend? : String?
  #     @@backend
  #   end
  #
  #   def backend : String
  #     @@backend.not_nil!("Robot.backend cannot be nil")
  #   end
  # end
  # ```
  #
  # Refer to [Getters](#getters) for general details.
  MARKDOWN
  g.gen_getter!

  f.puts <<-MARKDOWN
  # Generates setter method(s) to set class variable(s).
  #
  # For example writing:
  #
  # ```
  # class Robot
  #   class_setter factories
  # end
  # ```
  #
  # Is equivalent to writing:
  #
  # ```
  # class Robot
  #   @@factories
  #
  #   def self.factories=(@@factories)
  #   end
  # end
  # ```
  #
  # Refer to [Setters](#setters) for general details.
  MARKDOWN
  g.gen_setter

  g.gen_property
  g.gen_property?
  g.gen_property!

  f.puts "end"
end
