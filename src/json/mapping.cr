module JSON
  # The `JSON.mapping` macro defines how an object is mapped to JSON.
  #
  # ### Example
  #
  # ```
  # require "json"
  #
  # class Location
  #   JSON.mapping({
  #     lat: Float64,
  #     lng: Float64,
  #   })
  # end
  #
  # class House
  #   JSON.mapping({
  #     address:  String,
  #     location: {type: Location, nilable: true},
  #   })
  # end
  #
  # house = House.from_json(%({"address": "Crystal Road 1234", "location": {"lat": 12.3, "lng": 34.5}}))
  # house.address  # => "Crystal Road 1234"
  # house.location # => #&lt;Location:0x10cd93d80 @lat=12.3, @lng=34.5>
  # house.to_json  # => %({"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}})
  # ```
  #
  # ### Usage
  #
  # `JSON.mapping` must receive a hash literal whose keys will define Crystal properties.
  #
  # The value of each key can be a single type (not a union type). Primitive types (numbers, string, boolean and nil)
  # are supported, as well as custom objects which use `JSON.mapping` or define a `new` method
  # that accepts a `JSON::PullParser` and returns an object from it.
  #
  # The value can also be another hash literal with the following options:
  # * **type**: (required) the single type described above (you can use `JSON::Any` too)
  # * **key**: the property name in the JSON document (as opposed to the property name in the Crystal code)
  # * **nilable**: if true, the property can be `Nil`
  # * **default**: value to use if the property is missing in the JSON document, or if it's `null` and `nilable` was not set to `true`. If the default value creates a new instance of an object (for example `[1, 2, 3]` or `SomeObject.new`), a different instance will be used each time a JSON document is parsed.
  # * **emit_null**: if true, emits a `null` value for nilable properties (by default nulls are not emitted)
  # * **converter**: specify an alternate type for parsing and generation. The converter must define `from_json(JSON::PullParser)` and `to_json(value, IO)` as class methods.
  #
  # The mapping also automatically defines Crystal properties (getters and setters) for each
  # of the keys. It doesn't define a constructor accepting those arguments, but you can provide
  # an overload.
  #
  # The macro basically defines a constructor accepting a `JSON::PullParser` that reads from
  # it and initializes this type's instance variables. It also defines a `to_json(IO)` method
  # by invoking `to_json(IO)` on each of the properties (unless a converter is specified, in
  # which case `to_json(value, IO)` is invoked).
  #
  # This macro also declares instance variables of the types given in the mapping.
  #
  # If `strict` is true, unknown properties in the JSON
  # document will raise a parse exception. The default is `false`, so unknown properties
  # are silently ignored.
  macro mapping(properties, strict = false)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) %}
    {% end %}

    {% for key, value in properties %}
      @{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }}

      def {{key.id}}=(_{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }})
        @{{key.id}} = _{{key.id}}
      end

      def {{key.id}}
        @{{key.id}}
      end
    {% end %}

    def initialize(%pull : JSON::PullParser)
      {% for key, value in properties %}
        %var{key.id} = nil
        %found{key.id} = false
      {% end %}

      %pull.read_object do |key|
        case key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            %found{key.id} = true
            %var{key.id} =
              {% if value[:nilable] || value[:default] != nil %} %pull.read_null_or { {% end %}

              {% if value[:converter] %}
                {{value[:converter]}}.from_json(%pull)
              {% else %}
                {{value[:type]}}.new(%pull)
              {% end %}

            {% if value[:nilable] || value[:default] != nil %} } {% end %}
        {% end %}
        else
          {% if strict %}
            raise JSON::ParseException.new("unknown json attribute: #{key}", 0, 0)
          {% else %}
            %pull.skip
          {% end %}
        end
      end

      {% for key, value in properties %}
        {% unless value[:nilable] || value[:default] != nil %}
          if %var{key.id}.is_a?(Nil) && !%found{key.id}
            raise JSON::ParseException.new("missing json attribute: {{(value[:key] || key).id}}", 0, 0)
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
          @{{key.id}} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : %var{key.id}
        {% else %}
          @{{key.id}} = %var{key.id}.not_nil!
        {% end %}
      {% end %}
    end

    def to_json(io : IO)
      io.json_object do |json|
        {% for key, value in properties %}
          _{{key.id}} = @{{key.id}}

          {% unless value[:emit_null] %}
            unless _{{key.id}}.is_a?(Nil)
          {% end %}

            json.field({{value[:key] || key.id.stringify}}) do
              {% if value[:converter] %}
                if _{{key.id}}
                  {{ value[:converter] }}.to_json(_{{key.id}}, io)
                else
                  nil.to_json(io)
                end
              {% else %}
                _{{key.id}}.to_json(io)
              {% end %}
            end

          {% unless value[:emit_null] %}
            end
          {% end %}
        {% end %}
      end
    end
  end
end
