module JSON
  annotation Field
  end

  # The `JSON::Serializable` module automatically generates methods for JSON serialization when included.
  #
  # ### Example
  #
  # ```
  # require "json"
  #
  # class Location
  #   include JSON::Serializable
  #
  #   @[JSON::Field(key: "lat")]
  #   property latitude : Float64
  #
  #   @[JSON::Field(key: "lng")]
  #   property longitude : Float64
  # end
  #
  # class House
  #   include JSON::Serializable
  #   property address : String
  #   property location : Location?
  # end
  #
  # house = House.from_json(%({"address": "Crystal Road 1234", "location": {"lat": 12.3, "lng": 34.5}}))
  # house.address  # => "Crystal Road 1234"
  # house.location # => #<Location:0x10cd93d80 @latitude=12.3, @longitude=34.5>
  # house.to_json  # => %({"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}})
  #
  # houses = Array(House).from_json(%([{"address": "Crystal Road 1234", "location": {"lat": 12.3, "lng": 34.5}}]))
  # houses.size    # => 1
  # houses.to_json # => %([{"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}}])
  # ```
  #
  # ### Usage
  #
  # Including `JSON::Serializable` will create `#to_json` and `self.from_json` methods on the current class,
  # and a constructor which takes a `JSON::PullParser`. By default, these methods serialize into a json
  # object containing the value of every instance variable, the keys being the instance variable name.
  # Most primitives and collections supported as instance variable values (string, integer, array, hash, etc.),
  # along with objects which define to_json and a constructor taking a `JSON::PullParser`.
  # Union types are also supported, including unions with nil. If multiple types in a union parse correctly,
  # it is undefined which one will be chosen.
  #
  # To change how individual instance variables are parsed and serialized, the annotation `JSON::Field`
  # can be placed on the instance variable. Annotating property, getter and setter macros is also allowed.
  # ```
  # require "json"
  #
  # class A
  #   include JSON::Serializable
  #
  #   @[JSON::Field(key: "my_key", emit_null: true)]
  #   getter a : Int32?
  # end
  # ```
  #
  # `JSON::Field` properties:
  # * **ignore**: if `true` skip this field in serialization and deserialization (by default false)
  # * **key**: the value of the key in the json object (by default the name of the instance variable)
  # * **root**: assume the value is inside a JSON object with a given key (see `Object.from_json(string_or_io, root)`)
  # * **converter**: specify an alternate type for parsing and generation. The converter must define `from_json(JSON::PullParser)` and `to_json(value, JSON::Builder)` as class methods. Examples of converters are `Time::Format` and `Time::EpochConverter` for `Time`.
  # * **presence**: if `true`, a `@{{key}}_present` instance variable will be generated when the key was present (even if it has a `null` value), `false` by default
  # * **emit_null**: if `true`, emits a `null` value for nilable property (by default nulls are not emitted)
  #
  # Deserialization also respects default values of variables:
  # ```
  # require "json"
  #
  # struct A
  #   include JSON::Serializable
  #   @a : Int32
  #   @b : Float64 = 1.0
  # end
  #
  # A.from_json(%<{"a":1}>) # => A(@a=1, @b=1.0)
  # ```
  #
  # ### Extensions: `JSON::Serializable::Strict` and `JSON::Serializable::Unmapped`.
  #
  # If the `JSON::Serializable::Strict` module is included, unknown properties in the JSON
  # document will raise a parse exception. By default the unknown properties
  # are silently ignored.
  # If the `JSON::Serializable::Unmapped` module is included, unknown properties in the JSON
  # document will be stored in a `Hash(String, JSON::Any)`. On serialization, any keys inside json_unmapped
  # will be serialized and appended to the current json object.
  # ```
  # require "json"
  #
  # struct A
  #   include JSON::Serializable
  #   include JSON::Serializable::Unmapped
  #   @a : Int32
  # end
  #
  # a = A.from_json(%({"a":1,"b":2})) # => A(@json_unmapped={"b" => 2_i64}, @a=1)
  # a.to_json                         # => {"a":1,"b":2}
  # ```
  #
  #
  # ### Class annotation `JSON::Serializable::Options`
  #
  # supported properties:
  # * **emit_nulls**: if `true`, emits a `null` value for all nilable properties (by default nulls are not emitted)
  #
  # ```
  # require "json"
  #
  # @[JSON::Serializable::Options(emit_nulls: true)]
  # class A
  #   include JSON::Serializable
  #   @a : Int32?
  # end
  # ```
  module Serializable
    annotation Options
    end

    macro included
      # Define a `new` directly in the included type,
      # so it overloads well with other possible initializes

      def self.new(pull : ::JSON::PullParser)
        instance = allocate
        instance.initialize(__pull_for_json_serializable: pull)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      # When the type is inherited, carry over the `new`
      # so it can compete with other possible intializes

      macro inherited
        def self.new(pull : ::JSON::PullParser)
          super
        end
      end
    end

    def initialize(*, __pull_for_json_serializable pull : ::JSON::PullParser)
      {% begin %}
        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::JSON::Field) %}
          {% unless ann && ann[:ignore] %}
            {%
              properties[ivar.id] = {
                type:        ivar.type,
                key:         ((ann && ann[:key]) || ivar).id.stringify,
                has_default: ivar.has_default_value?,
                default:     ivar.default_value,
                nilable:     ivar.type.nilable?,
                root:        ann && ann[:root],
                converter:   ann && ann[:converter],
                presence:    ann && ann[:presence],
              }
            %}
          {% end %}
        {% end %}

        {% for name, value in properties %}
          %var{name} = nil
          %found{name} = false
        {% end %}

        %location = pull.location
        begin
          pull.read_begin_object
        rescue exc : ::JSON::ParseException
          raise ::JSON::MappingError.new(exc.message, self.class.to_s, nil, *%location, exc)
        end
        while pull.kind != :end_object
          %key_location = pull.location
          key = pull.read_object_key
          case key
          {% for name, value in properties %}
            when {{value[:key]}}
              %found{name} = true
              begin
                %var{name} =
                  {% if value[:nilable] || value[:has_default] %} pull.read_null_or { {% end %}

                  {% if value[:root] %}
                    pull.on_key!({{value[:root]}}) do
                  {% end %}

                  {% if value[:converter] %}
                    {{value[:converter]}}.from_json(pull)
                  {% else %}
                    ::Union({{value[:type]}}).new(pull)
                  {% end %}

                  {% if value[:root] %}
                    end
                  {% end %}

                {% if value[:nilable] || value[:has_default] %} } {% end %}
              rescue exc : ::JSON::ParseException
                raise ::JSON::MappingError.new(exc.message, self.class.to_s, {{value[:key]}}, *%key_location, exc)
              end
          {% end %}
          else
            on_unknown_json_attribute(pull, key, %key_location)
          end
        end
        pull.read_next

        {% for name, value in properties %}
          {% unless value[:nilable] || value[:has_default] %}
            if %var{name}.nil? && !%found{name} && !::Union({{value[:type]}}).nilable?
              raise ::JSON::MappingError.new("Missing JSON attribute: {{value[:key].id}}", self.class.to_s, nil, *%location, nil)
            end
          {% end %}

          {% if value[:nilable] %}
            {% if value[:has_default] != nil %}
              @{{name}} = %found{name} ? %var{name} : {{value[:default]}}
            {% else %}
              @{{name}} = %var{name}
            {% end %}
          {% elsif value[:has_default] %}
            @{{name}} = %var{name}.nil? ? {{value[:default]}} : %var{name}
          {% else %}
            @{{name}} = (%var{name}).as({{value[:type]}})
          {% end %}

          {% if value[:presence] %}
            @{{name}}_present = %found{name}
          {% end %}
        {% end %}
      {% end %}
      after_initialize
    end

    protected def after_initialize
    end

    protected def on_unknown_json_attribute(pull, key, key_location)
      pull.skip
    end

    protected def on_to_json(json : ::JSON::Builder)
    end

    def to_json(json : ::JSON::Builder)
      {% begin %}
        {% options = @type.annotation(::JSON::Serializable::Options) %}
        {% emit_nulls = options && options[:emit_nulls] %}

        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::JSON::Field) %}
          {% unless ann && ann[:ignore] %}
            {%
              properties[ivar.id] = {
                type:      ivar.type,
                key:       ((ann && ann[:key]) || ivar).id.stringify,
                root:      ann && ann[:root],
                converter: ann && ann[:converter],
                emit_null: (ann && (ann[:emit_null] != nil) ? ann[:emit_null] : emit_nulls),
              }
            %}
          {% end %}
        {% end %}

        json.object do
          {% for name, value in properties %}
            _{{name}} = @{{name}}

            {% unless value[:emit_null] %}
              unless _{{name}}.nil?
            {% end %}

              json.field({{value[:key]}}) do
                {% if value[:root] %}
                  {% if value[:emit_null] %}
                    if _{{name}}.nil?
                      nil.to_json(json)
                    else
                  {% end %}

                  json.object do
                    json.field({{value[:root]}}) do
                {% end %}

                {% if value[:converter] %}
                  if _{{name}}
                    {{ value[:converter] }}.to_json(_{{name}}, json)
                  else
                    nil.to_json(json)
                  end
                {% else %}
                  _{{name}}.to_json(json)
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
          on_to_json(json)
        end
      {% end %}
    end

    module Strict
      protected def on_unknown_json_attribute(pull, key, key_location)
        raise ::JSON::MappingError.new("Unknown JSON attribute: #{key}", self.class.to_s, nil, *key_location, nil)
      end
    end

    module Unmapped
      @[JSON::Field(ignore: true)]
      property json_unmapped = Hash(String, JSON::Any).new

      protected def on_unknown_json_attribute(pull, key, key_location)
        json_unmapped[key] = begin
          JSON::Any.new(pull)
        rescue exc : ::JSON::ParseException
          raise ::JSON::MappingError.new(exc.message, self.class.to_s, key, *key_location, exc)
        end
      end

      protected def on_to_json(json)
        json_unmapped.each do |key, value|
          json.field(key) { value.to_json(json) }
        end
      end
    end
  end
end
