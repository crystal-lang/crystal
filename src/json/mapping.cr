module JSON
  # The `JSON.mapping` macro defines how an object is mapped to JSON.
  #
  # ### Example
  #
  # ```
  # require "json"
  #
  # class Location
  #   JSON.mapping(
  #     lat: Float64,
  #     lng: Float64,
  #   )
  # end
  #
  # class House
  #   JSON.mapping(
  #     address: String,
  #     location: {type: Location, nilable: true},
  #   )
  # end
  #
  # house = House.from_json(%({"address": "Crystal Road 1234", "location": {"lat": 12.3, "lng": 34.5}}))
  # house.address  # => "Crystal Road 1234"
  # house.location # => #<Location:0x10cd93d80 @lat=12.3, @lng=34.5>
  # house.to_json  # => %({"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}})
  # ```
  #
  # ### Usage
  #
  # `JSON.mapping` must receive a series of named arguments, or a named tuple literal, or a hash literal,
  # whose keys will define Crystal properties.
  #
  # The value of each key can be a single type (not a union type). Primitive types (numbers, string, boolean and nil)
  # are supported, as well as custom objects which use `JSON.mapping` or define a `new` method
  # that accepts a `JSON::PullParser` and returns an object from it.
  #
  # The value can also be another hash literal with the following options:
  # * **type**: (required) the single type described above (you can use `JSON::Any` too)
  # * **key**: the property name in the JSON document (as opposed to the property name in the Crystal code)
  # * **nilable**: if `true`, the property can be `Nil`. Passing `T?` as a type has the same effect.
  # * **default**: value to use if the property is missing in the JSON document, or if it's `null` and `nilable` was not set to `true`. If the default value creates a new instance of an object (for example `[1, 2, 3]` or `SomeObject.new`), a different instance will be used each time a JSON document is parsed.
  # * **emit_null**: if `true`, emits a `null` value for nilable properties (by default nulls are not emitted)
  # * **converter**: specify an alternate type for parsing and generation. The converter must define `from_json(JSON::PullParser)` and `to_json(value, JSON::Builder)` as class methods. Examples of converters are `Time::Format` and `Time::EpochConverter` for `Time`.
  # * **root**: assume the value is inside a JSON object with a given key (see `Object.from_json(string_or_io, root)`)
  # * **setter**: if `true`, will generate a setter for the variable, `true` by default
  # * **getter**: if `true`, will generate a getter for the variable, `true` by default
  # * **presence**: if `true`, a `{{key}}_present?` method will be generated when the key was present (even if it has a `null` value), `false` by default
  #
  # This macro by default defines getters and setters for each variable (this can be overrided with *setter* and *getter*).
  # The mapping doesn't define a constructor accepting these variables as arguments, but you can provide an overload.
  #
  # The macro basically defines a constructor accepting a `JSON::PullParser` that reads from
  # it and initializes this type's instance variables. It also defines a `to_json(JSON::Builder)` method
  # by invoking `to_json(JSON::Builder)` on each of the properties (unless a converter is specified, in
  # which case `to_json(value, JSON::Builder)` is invoked).
  #
  # This macro also declares instance variables of the types given in the mapping.
  #
  # If *strict* is `true`, unknown properties in the JSON
  # document will raise a parse exception. The default is `false`, so unknown properties
  # are silently ignored.
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

    def initialize(%pull : ::JSON::PullParser)
      {% for key, value in properties %}
        %var{key.id} = nil
        %found{key.id} = false
      {% end %}

      %location = %pull.location
      %pull.read_begin_object
      while %pull.kind != :end_object
        %key_location = %pull.location
        key = %pull.read_object_key
        case key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            %found{key.id} = true

            %var{key.id} =
              {% if value[:nilable] || value[:default] != nil %} %pull.read_null_or { {% end %}

              {% if value[:root] %}
                %pull.on_key!({{value[:root]}}) do
              {% end %}

              {% if value[:converter] %}
                {{value[:converter]}}.from_json(%pull)
              {% elsif value[:type].is_a?(Path) || value[:type].is_a?(Generic) %}
                {{value[:type]}}.new(%pull)
              {% else %}
                ::Union({{value[:type]}}).new(%pull)
              {% end %}

              {% if value[:root] %}
                end
              {% end %}

            {% if value[:nilable] || value[:default] != nil %} } {% end %}

        {% end %}
        else
          {% if strict %}
            raise ::JSON::ParseException.new("Unknown json attribute: #{key}", *%key_location)
          {% else %}
            %pull.skip
          {% end %}
        end
      end
      %pull.read_next

      {% for key, value in properties %}
        {% unless value[:nilable] || value[:default] != nil %}
          if %var{key.id}.nil? && !%found{key.id} && !::Union({{value[:type]}}).nilable?
            raise ::JSON::ParseException.new("Missing json attribute: {{(value[:key] || key).id}}", *%location)
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
          @{{key.id}} = (%var{key.id}).as({{value[:type]}})
        {% end %}
      {% end %}

      {% for key, value in properties %}
        {% if value[:presence] %}
          @{{key.id}}_present = %found{key.id}
        {% end %}
      {% end %}
    end

    def to_json(json : ::JSON::Builder)
      json.object do
        {% for key, value in properties %}
          _{{key.id}} = @{{key.id}}

          {% unless value[:emit_null] %}
            unless _{{key.id}}.nil?
          {% end %}

            json.field({{value[:key] || key.id.stringify}}) do
              {% if value[:root] %}
                {% if value[:emit_null] %}
                  if _{{key.id}}.nil?
                    nil.to_json(json)
                  else
                {% end %}

                json.object do
                  json.field({{value[:root]}}) do
              {% end %}

              {% if value[:converter] %}
                if _{{key.id}}
                  {{ value[:converter] }}.to_json(_{{key.id}}, json)
                else
                  nil.to_json(json)
                end
              {% else %}
                _{{key.id}}.to_json(json)
              {% end %}

              {% if value[:root] %}
                {% if value[:emit_null] %}
                  end
                {% end %}
                  end
                end
              {% end %}
            end

          {% unless value[:emit_null] %}
            end
          {% end %}
        {% end %}
      end
    end
  end

  # This is a convenience method to allow invoking `JSON.mapping`
  # with named arguments instead of with a hash/named-tuple literal.
  macro mapping(**properties)
    ::JSON.mapping({{properties}})
  end
end
