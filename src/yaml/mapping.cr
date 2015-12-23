module YAML
  # The `YAML.mapping` macro defines how an object is mapped to YAML.
  #
  # It takes hash literal as argument, in which attributes and types are defined.
  # Once defined, `Object#from_yaml` populates properties of the class from the
  # YAML document.
  #
  # ```crystal
  # require "yaml"
  #
  # class Employee
  #   YAML.mapping({
  #     title: String,
  #     name:  String,
  #   })
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
  # ```crystal
  # employee = Employee.from_yaml("title: Manager\nname: John\nage: 30")
  # employee.age # => undefined method 'age'.
  #
  # employee = Employee.from_yaml("title: Manager")
  # # => ParseException: missing yaml attribute: name
  # ```
  #
  # You can also define attributes for each property.
  #
  # ```crystal
  # class Employee
  #   YAML.mapping({
  #     title: String,
  #     name:  {
  #       type:    String,
  #       nilable: true,
  #       key:     "firstname",
  #     },
  #   })
  # end
  # ```
  #
  # Available attributes:
  #
  # * *type* (required) defines its type. In the example above, *title: String* is a shortcut to *title: {type: String}*.
  # * *nilable* defines if a property can be a `Nil`.
  # * *key* defines whick key to read from a YAML document. It defaults to the name of the property.
  # * *converter* takes an alternate type for parsing. It requires a `#from_yaml` method in that class, and returns an instance of the given type.
  macro mapping(properties, strict = false)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) %}
    {% end %}

    {% for key, value in properties %}
      def {{key.id}}=(_{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }})
        @{{key.id}} = _{{key.id}}
      end

      def {{key.id}}
        @{{key.id}}
      end
    {% end %}

    def initialize(%pull : YAML::PullParser)
      {% for key, value in properties %}
        %var{key.id} = nil
      {% end %}

      %pull.read_mapping_start
      while %pull.kind != YAML::EventKind::MAPPING_END
        key = %pull.read_scalar.not_nil!
        case key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            %var{key.id} =
            {% if value[:nilable] == true %} %pull.read_null_or { {% end %}

            {% if value[:converter] %}
              {{value[:converter]}}.from_yaml(%pull)
            {% else %}
              {{value[:type]}}.new(%pull)
            {% end %}

            {% if value[:nilable] == true %} } {% end %}
        {% end %}
        else
          {% if strict %}
            raise YAML::ParseException.new("unknown yaml attribute: #{key}", 0, 0)
          {% else %}
            %pull.skip
          {% end %}
        end
      end
      %pull.read_next

      {% for key, value in properties %}
        {% unless value[:nilable] %}
          if %var{key.id}.is_a?(Nil)
            raise YAML::ParseException.new("missing yaml attribute: {{(value[:key] || key).id}}", 0, 0)
          end
        {% end %}
      {% end %}

      {% for key, value in properties %}
        @{{key.id}} = %var{key.id}
      {% end %}
    end
  end
end
