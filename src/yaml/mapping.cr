module YAML
  # The `YAML.mapping` macro defines how an object is mapped to YAML.
  #
  # It takes named arguments, a named tuple literal or a hash literal as argument,
  # in which attributes and types are defined.
  # Once defined, `Object#from_yaml` populates properties of the class from the
  # YAML document.
  #
  # ```
  # require "yaml"
  #
  # class Employee
  #   YAML.mapping(
  #     title: String,
  #     name: String,
  #   )
  # end
  #
  # employee = Employee.from_yaml("title: Manager\nname: John")
  # employee.title # => "Manager"
  # employee.name  # => "John"
  #
  # employee.name = "Jenny"
  # employee.name # => "Jenny"
  # ```
  #
  # Attributes not mapped with `YAML.mapping` are not defined as properties.
  # Also, missing attributes raise a `ParseException`.
  #
  # ```
  # employee = Employee.from_yaml("title: Manager\nname: John\nage: 30")
  # employee.age # undefined method 'age'. (compile error)
  #
  # Employee.from_yaml("title: Manager") # raises YAML::ParseException
  # ```
  #
  # You can also define attributes for each property.
  #
  # ```
  # class Employer
  #   YAML.mapping(
  #     title: String,
  #     name: {
  #       type:    String,
  #       nilable: true,
  #       key:     "firstname",
  #     },
  #   )
  # end
  # ```
  #
  # Available attributes:
  #
  # * *type* (required) defines its type. In the example above, *title: String* is a shortcut to *title: {type: String}*.
  # * *nilable* defines if a property can be a `Nil`. Passing `T?` as a type has the same effect.
  # * **default**: value to use if the property is missing in the YAML document, or if it's `null` and `nilable` was not set to `true`. If the default value creates a new instance of an object (for example `[1, 2, 3]` or `SomeObject.new`), a different instance will be used each time a YAML document is parsed.
  # * *key* defines which key to read from a YAML document. It defaults to the name of the property.
  # * *converter* takes an alternate type for parsing. It requires a `#from_yaml` method in that class, and returns an instance of the given type. Examples of converters are `Time::Format` and `Time::EpochConverter` for `Time`.
  # * **setter**: if `true`, will generate a setter for the variable, `true` by default
  # * **getter**: if `true`, will generate a getter for the variable, `true` by default
  # * **presence**: if `true`, a `{{key}}_present?` method will be generated when the key was present (even if it has a `null` value), `false` by default
  #
  # This macro by default defines getters and setters for each variable (this can be overrided with *setter* and *getter*).
  # The mapping doesn't define a constructor accepting these variables as arguments, but you can provide an overload.
  #
  # The macro basically defines a constructor accepting a `YAML::PullParser` that reads from
  # it and initializes this type's instance variables.
  #
  # This macro also declares instance variables of the types given in the mapping.
  macro mapping(properties, strict = false)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
    {% end %}

    {% for key, value in properties %}
      @{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }}

      {% if value[:setter] == nil ? true : value[:setter] %}
        def {{key.id}}=(_{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }})
          @{{key.id}} = _{{key.id}}
        end
      {% end %}

      {% if value[:getter] == nil ? true : value[:getter] %}
        def {{key.id}}
          @{{key.id}}
        end
      {% end %}

      {% if value[:presence] %}
        @{{key.id}}_present : Bool = false

        def {{key.id}}_present?
          @{{key.id}}_present
        end
      {% end %}
    {% end %}

    def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      ctx.read_alias(node, \{{@type}}) do |obj|
        return obj
      end

      instance = allocate

      ctx.record_anchor(node, instance)

      instance.initialize(ctx, node, nil)
      instance
    end

    # `new` and `initialize` with just `pull` as an argument collide
    # and the compiler just sees the last one. This is why we add a
    # dummy argument.
    #
    # FIXME: remove the dummy argument if we ever fix this.

    def initialize(ctx : YAML::ParseContext, node : ::YAML::Nodes::Node, _dummy : Nil)
      {% for key, value in properties %}
        %var{key.id} = nil
        %found{key.id} = false
      {% end %}

      case node
      when YAML::Nodes::Mapping
        YAML::Schema::Core.each(node) do |key_node, value_node|
          unless key_node.is_a?(YAML::Nodes::Scalar)
            key_node.raise "Expected scalar as key for mapping"
          end

          key = key_node.value

          case key
          {% for key, value in properties %}
            when {{value[:key] || key.id.stringify}}
              %found{key.id} = true

              %var{key.id} =
                {% if value[:nilable] || value[:default] != nil %} YAML::Schema::Core.parse_null_or(value_node) { {% end %}

                {% if value[:converter] %}
                  {{value[:converter]}}.from_yaml(ctx, value_node)
                {% elsif value[:type].is_a?(Path) || value[:type].is_a?(Generic) %}
                  {{value[:type]}}.new(ctx, value_node)
                {% else %}
                  ::Union({{value[:type]}}).new(ctx, value_node)
                {% end %}

                {% if value[:nilable] || value[:default] != nil %} } {% end %}
          {% end %}
          else
            {% if strict %}
              key_node.raise "Unknown yaml attribute: #{key}"
            {% end %}
          end
        end
      when YAML::Nodes::Scalar
        if node.value.empty? && node.style.plain? && !node.tag
          # We consider an empty scalar as an empty mapping
        else
          node.raise "Expected mapping, not #{node.class}"
        end
      else
        node.raise "Expected mapping, not #{node.class}"
      end

      {% for key, value in properties %}
        {% unless value[:nilable] || value[:default] != nil %}
          if %var{key.id}.nil? && !%found{key.id} && !::Union({{value[:type]}}).nilable?
            node.raise "Missing yaml attribute: {{(value[:key] || key).id}}"
          end
        {% end %}
      {% end %}

      {% for key, value in properties %}
        {% if value[:nilable] %}
          {% if value[:default] != nil %}
            @{{key.id}} = %found{key.id} ? %var{key.id} : {{value[:default]}}
          {% else %}
            @{{key.id}} = %var{key.id}
          {% end %}
        {% elsif value[:default] != nil %}
          @{{key.id}} = %var{key.id}.nil? ? {{value[:default]}} : %var{key.id}
        {% else %}
          @{{key.id}} = %var{key.id}.as({{value[:type]}})
        {% end %}
      {% end %}

      {% for key, value in properties %}
        {% if value[:presence] %}
          @{{key.id}}_present = %found{key.id}
        {% end %}
      {% end %}
    end

    def to_yaml(%yaml : ::YAML::Nodes::Builder)
      %yaml.mapping(reference: self) do
        {% for key, value in properties %}
          _{{key.id}} = @{{key.id}}

          unless _{{key.id}}.nil?
            # Key
            {{value[:key] || key.id.stringify}}.to_yaml(%yaml)

            # Value
            {% if value[:converter] %}
              {{ value[:converter] }}.to_yaml(_{{key.id}}, %yaml)
            {% else %}
              _{{key.id}}.to_yaml(%yaml)
            {% end %}
          end
        {% end %}
      end
    end
  end

  # This is a convenience method to allow invoking `YAML.mapping`
  # with named arguments instead of with a hash/named-tuple literal.
  macro mapping(**properties)
    ::YAML.mapping({{properties}})
  end
end
