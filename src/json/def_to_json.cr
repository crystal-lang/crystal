module JSON
  # The `def_to_json` macro generates a `to_json(json : JSON::Builder)` method based on provided *mappings*.
  #
  # It is a lightweight alternative to `JSON.mapping` if you don't need to declare instance variables and a parser.
  #
  # The generated method invoks `to_json(JSON::Builder)` on each of the values returned by the *value* expression,
  # or - if a converter is specified - `to_json(value, JSON::Builder)` on the converter.
  #
  # ### Example
  #
  # ```
  # require "json"
  #
  # record Location, lat : Float64, long : Float64 do
  #   JSON.def_to_json([lat, long])
  # end
  #
  # record House, street : String, street_number : Int32, location : Location do
  #   JSON.def_to_json(
  #     address: _,
  #     loc: location,
  #     empty_field: {emit_null: true},
  #     next_number: {value: street_number + 1},
  #   )
  #
  #   def address
  #     "#{street} #{street_number}"
  #   end
  #
  #   def empty_field
  #     nil
  #   end
  # end
  #
  # house = House.new("Crystal Road", 1234, Location.new(12.3, 34.5))
  # house.to_json # => %({"address":"Crystal Road 1234","loc":{"lat":12.3,"long":34.5},"empty_field":null,"next_number":1235})
  # ```
  #
  # ### Usage
  #
  # `JSON.def_to_json` must receive a series of named arguments, or a named tuple literal, or a hash literal,
  # whose keys will define JSON properties.
  #
  # The value of each key can be a hash or named tuple literal with the following options:
  # * **value**: the Crystal expression to determine the value. By default it is equal to the property name of the current  *key*
  #   on the Crystal object (as opposed to the key in the JSON document)
  # * **emit_null**: if `true`, emits a `null` value if the *value* is `nil` (by default nulls are not emitted)
  # * **converter**: specify an alternate type for generation. The converter must define `to_json(value, JSON::Builder)` as class methods. Examples of converters are `Time::Format` and `Time::EpochConverter` for `Time`.
  # * **root**: assume the value is inside a JSON object with a given key
  #
  # If it is not a hash or named tuple literal, the expression will be interpreted as `value` parameter. As a shortcut `_` represents
  # a call to a method of the same name as `key`: so `location: _`, ``location: location` and `location: { value: location }` are equivalent.
  macro def_to_json(mappings)
    def to_json(json : ::JSON::Builder)
      json.object do
        {% for key, options in mappings %}
          {% if options.is_a?(Underscore) %}
            {% options = {value: key} %}
          {% elsif !options.is_a?(HashLiteral) && !options.is_a?(NamedTupleLiteral) %}
            {% options = {value: options} %}
          {% end %}
          ::JSON.emit_value_to_json({{(options[:value] || key).id}}, {{key.id.stringify}}, {{options}})
        {% end %}
      end
    end
  end

  # This is a convenience method to allow invoking `JSON.def_to_json`
  # with named arguments instead of with a hash/named-tuple literal.
  macro def_to_json(**mappings)
    ::JSON.def_to_json({{mappings}})
  end

  # This `def_to_json` macro generates a `to_json(value : {{type}}, json : JSON::Builder)` method based on provided type and mappings.
  #
  # This is useful to create a JSON converter which responds to a number of `to_json(value, builder : JSON::Builder)` overloads.
  #
  # In contrast to the `to_json(JSON::Builder)` method defined by `def_to_json(mapping)` the values for this JSON generator
  # are retrieved from calling a method on the object provided as the first argument whose type is declared as first argument
  # to this macro.
  #
  # ```
  # require "json"
  #
  # module NeighborhoodConverter
  #   extend self
  #   JSON.def_to_json(House, {street_number: _})
  # end
  #
  # class House
  #   getter street : String
  #   getter street_number : Int32
  #   getter neighbor : House? = nil
  #
  #   JSON.def_to_json(
  #     address: _,
  #     neighbor: {converter: NeighborhoodConverter}
  #   )
  #
  #   def initialize(@street, @street_number, @neighbor = nil)
  #   end
  #
  #   def address
  #     "#{street} #{street_number}"
  #   end
  # end
  #
  # neighbor = House.new("Crystal Road", 1235)
  # house = House.new("Crystal Road", 1234, neighbor)
  # house.to_json # => %({"address":"Crystal Road 1234","neighbor":{"street_number":1235}})
  # ```
  macro def_to_json(type, mappings)
    def to_json(value : {{type.id}}, json : ::JSON::Builder)
      json.object do
        {% for key, options in mappings %}
          {% if options.is_a?(Underscore) %}
            {% options = {value: key} %}
          {% elsif !options.is_a?(HashLiteral) && !options.is_a?(NamedTupleLiteral) %}
            {% options = {value: options} %}
          {% end %}
          ::JSON.emit_value_to_json(value.{{(options[:value] || key).id}}, {{key.id.stringify}}, {{options}})
        {% end %}
      end
    end
  end

  # This is a convenience method to allow invoking `JSON.def_to_json`
  # with named arguments instead of with a hash/named-tuple literal.
  macro def_to_json(type, **mappings)
    ::JSON.def_to_json({{type}}, {{mappings}})
  end

  # The `StringConverter` has a class method `to_json` which can be used as a converter for `JSON.def_to_json`. The value is added
  # to the builder as a string.
  module StringConverter
    def self.to_json(value, builder)
      value.to_s.to_json(builder)
    end
  end

  # :nodoc:
  macro emit_value_to_json(value_expression, json_key, options)
    # this macro is used by `.mapping` and `.def_to_json`
    # TODO: Remove wrapping branch keywords in macro expressions after #4769 is included in the next release (after 0.23.1)
    # TODO: Replace {{value_expression.id}} with %value in unwrapped keywords
    %value = {{value_expression.id}}
    {% unless options[:emit_null] %}
      {{ "unless (#{value_expression.id}).nil?".id }}
    {% end %}

      json.field({{json_key}}) do
        {% if options[:root] %}
          {% if options[:emit_null] %}
            {{ "if (#{value_expression.id}).nil?".id }}
              nil.to_json(json)
            {{ "else".id }}
          {% end %}

          {{ "json.object do".id }}
            {{ "json.field(#{options[:root]}) do".id }}
        {% end %}

        {% if options[:converter] %}
          if %value
            {{ options[:converter] }}.to_json(%value, json)
          else
            nil.to_json(json)
          end
        {% else %}
           %value.to_json(json)
        {% end %}

        {% if options[:root] %}
          {% if options[:emit_null] %}
            {{ "end".id }}
          {% end %}
            {{ "end".id }}
          {{ "end".id }}
        {% end %}
      end

    {% unless options[:emit_null] %}
      {{ "end".id }}
    {% end %}
  end
end
