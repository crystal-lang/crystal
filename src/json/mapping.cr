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
  #
  # houses = Array(House).from_json(%([{"address": "Crystal Road 1234", "location": {"lat": 12.3, "lng": 34.5}}]))
  # houses.size    # => 1
  # houses.to_json # => %([{"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}}])
  # ```
  #
  # ### Usage
  #
  # `JSON.mapping` must receive a series of named arguments, or a named tuple literal, or a hash literal,
  # whose keys will define Crystal properties.
  #
  # The value of each key can be a type. Primitive types (numbers, string, boolean and nil)
  # are supported, as well as custom objects which use `JSON.mapping` or define a `new` method
  # that accepts a `JSON::PullParser` and returns an object from it. Union types are supported,
  # if multiple types in the union can be mapped from the JSON, it is undefined which one will be chosen.
  #
  # The value can also be another hash literal with the following options:
  # * **type**: (required) the type described above (you can use `JSON::Any` too)
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
  macro mapping(_properties_, strict = false)
    {% for key, value in _properties_ %}
      {% _properties_[key] = {type: value} unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
    {% end %}

    {% for key, value in _properties_ %}
      {% _properties_[key][:key_id] = key.id.gsub(/\?$/, "") %}
    {% end %}

    {% for key, value in _properties_ %}
      @{{value[:key_id]}} : {{value[:type]}}{{ (value[:nilable] ? "?" : "").id }}

      {% if value[:setter] == nil ? true : value[:setter] %}
        def {{value[:key_id]}}=(_{{value[:key_id]}} : {{value[:type]}}{{ (value[:nilable] ? "?" : "").id }})
          @{{value[:key_id]}} = _{{value[:key_id]}}
        end
      {% end %}

      {% if value[:getter] == nil ? true : value[:getter] %}
        def {{key.id}} : {{value[:type]}}{{ (value[:nilable] ? "?" : "").id }}
          @{{value[:key_id]}}
        end
      {% end %}

      {% if value[:presence] %}
        @{{value[:key_id]}}_present : Bool = false

        def {{value[:key_id]}}_present?
          @{{value[:key_id]}}_present
        end
      {% end %}
    {% end %}

    def initialize(%pull : ::JSON::PullParser)
      {% for key, value in _properties_ %}
        %var{key.id} = nil
        %found{key.id} = false
      {% end %}

      %location = %pull.location
      begin
        %pull.read_begin_object
      rescue exc : ::JSON::ParseException
        raise ::JSON::MappingError.new(exc.message, self.class.to_s, nil, *%location, exc)
      end
      while %pull.kind != :end_object
        %key_location = %pull.location
        key = %pull.read_object_key
        case key
        {% for key, value in _properties_ %}
          when {{value[:key] || value[:key_id].stringify}}
            %found{key.id} = true
            begin
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
            rescue exc : ::JSON::ParseException
              raise ::JSON::MappingError.new(exc.message, self.class.to_s, {{value[:key] || value[:key_id].stringify}}, *%key_location, exc)
            end
        {% end %}
        else
          {% if strict %}
            raise ::JSON::MappingError.new("Unknown JSON attribute: #{key}", self.class.to_s, nil, *%key_location, nil)
          {% else %}
            %pull.skip
          {% end %}
        end
      end
      %pull.read_next

      {% for key, value in _properties_ %}
        {% unless value[:nilable] || value[:default] != nil %}
          if %var{key.id}.nil? && !%found{key.id} && !::Union({{value[:type]}}).nilable?
            raise ::JSON::MappingError.new("Missing JSON attribute: {{(value[:key] || value[:key_id]).id}}", self.class.to_s, nil, *%location, nil)
          end
        {% end %}

        {% if value[:nilable] %}
          {% if value[:default] != nil %}
            @{{value[:key_id]}} = %found{key.id} ? %var{key.id} : {{value[:default]}}
          {% else %}
            @{{value[:key_id]}} = %var{key.id}
          {% end %}
        {% elsif value[:default] != nil %}
          @{{value[:key_id]}} = %var{key.id}.nil? ? {{value[:default]}} : %var{key.id}
        {% else %}
          @{{value[:key_id]}} = (%var{key.id}).as({{value[:type]}})
        {% end %}

        {% if value[:presence] %}
          @{{value[:key_id]}}_present = %found{key.id}
        {% end %}
      {% end %}
    end

    def to_json(json : ::JSON::Builder)
      json.object do
        {% for key, value in _properties_ %}
          _{{value[:key_id]}} = @{{value[:key_id]}}

          {% unless value[:emit_null] %}
            unless _{{value[:key_id]}}.nil?
          {% end %}

            json.field({{value[:key] || value[:key_id].stringify}}) do
              {% if value[:root] %}
                {% if value[:emit_null] %}
                  if _{{value[:key_id]}}.nil?
                    nil.to_json(json)
                  else
                {% end %}

                json.object do
                  json.field({{value[:root]}}) do
              {% end %}

              {% if value[:converter] %}
                if _{{value[:key_id]}}
                  {{ value[:converter] }}.to_json(_{{value[:key_id]}}, json)
                else
                  nil.to_json(json)
                end
              {% else %}
                _{{value[:key_id]}}.to_json(json)
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
  macro mapping(**_properties_)
    ::JSON.mapping({{_properties_}})
  end

  class MappingError < ParseException
    getter klass : String
    getter attribute : String?

    def initialize(message : String?, @klass : String, @attribute : String?, line_number : Int32, column_number : Int32, cause)
      message = String.build do |io|
        io << message
        io << "\n  parsing "
        io << klass
        if attribute = @attribute
          io << '#' << attribute
        end
      end
      super(message, line_number, column_number, cause)
      if cause
        @line_number, @column_number = cause.location
      end
    end
  end
end
