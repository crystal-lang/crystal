module YAML
  annotation Field
  end

  # The `YAML::Serializable` module automatically generates methods for YAML serialization when included.
  #
  # ### Example
  #
  # ```
  # require "yaml"
  #
  # class Location
  #   include YAML::Serializable
  #
  #   @[YAML::Field(key: "lat")]
  #   property latitude : Float64
  #
  #   @[YAML::Field(key: "lng")]
  #   property longitude : Float64
  # end
  #
  # class House
  #   include YAML::Serializable
  #   property address : String
  #   property location : Location?
  # end
  #
  # house = House.from_yaml(%({"address": "Crystal Road 1234", "location": {"lat": 12.3, "lng": 34.5}}))
  # house.address  # => "Crystal Road 1234"
  # house.location # => #<Location:0x10cd93d80 @latitude=12.3, @longitude=34.5>
  # house.to_yaml  # => "---\naddress: Crystal Road 1234\nlocation:\n  lat: 12.3\n  lng: 34.5\n"
  #
  # houses = Array(House).from_yaml("---\n- address: Crystal Road 1234\n  location:\n    lat: 12.3\n    lng: 34.5\n")
  # houses.size    # => 1
  # houses.to_yaml # => "---\n- address: Crystal Road 1234\n  location:\n    lat: 12.3\n    lng: 34.5\n"
  # ```
  #
  # ### Usage
  #
  # Including `YAML::Serializable` will create `#to_yaml` and `self.from_yaml` methods on the current class,
  # and a constructor which takes a `YAML::PullParser`. By default, these methods serialize into a yaml
  # object containing the value of every instance variable, the keys being the instance variable name.
  # Most primitives and collections supported as instance variable values (string, integer, array, hash, etc.),
  # along with objects which define to_yaml and a constructor taking a `YAML::PullParser`.
  # Union types are also supported, including unions with nil. If multiple types in a union parse correctly,
  # it is undefined which one will be chosen.
  #
  # To change how individual instance variables are parsed and serialized, the annotation `YAML::Field`
  # can be placed on the instance variable. Annotating property, getter and setter macros is also allowed.
  # ```
  # require "yaml"
  #
  # class A
  #   include YAML::Serializable
  #
  #   @[YAML::Field(key: "my_key", emit_null: true)]
  #   getter a : Int32?
  # end
  # ```
  #
  # `YAML::Field` properties:
  # * **ignore**: if `true` skip this field in serialization and deserialization (by default false)
  # * **ignore_serialize**: If truthy, skip this field in serialization (default: `false`). The value can be any Crystal expression and is evaluated at runtime.
  # * **ignore_deserialize**: if `true` skip this field in deserialization (by default false)
  # * **key**: the value of the key in the yaml object (by default the name of the instance variable)
  # * **converter**: specify an alternate type for parsing and generation. The converter must define `from_yaml(YAML::ParseContext, YAML::Nodes::Node)` and `to_yaml(value, YAML::Nodes::Builder)`. Examples of converters are a `Time::Format` instance and `Time::EpochConverter` for `Time`.
  # * **presence**: if `true`, a `@{{key}}_present` instance variable will be generated when the key was present (even if it has a `null` value), `false` by default
  # * **emit_null**: if `true`, emits a `null` value for nilable property (by default nulls are not emitted)
  #
  # Deserialization also respects default values of variables:
  # ```
  # require "yaml"
  #
  # struct A
  #   include YAML::Serializable
  #   @a : Int32
  #   @b : Float64 = 1.0
  # end
  #
  # A.from_yaml("---\na: 1\n") # => A(@a=1, @b=1.0)
  # ```
  #
  # NOTE: `YAML::Serializable` defines an internal constructor on any including
  # type, which means the default constructor (`def initialize; end`) is absent
  # unless explicitly defined by the user, even when all instance variables have
  # a default initializer.
  #
  # ### Extensions: `YAML::Serializable::Strict` and `YAML::Serializable::Unmapped`.
  #
  # If the `YAML::Serializable::Strict` module is included, unknown properties in the YAML
  # document will raise a parse exception. By default the unknown properties
  # are silently ignored.
  # If the `YAML::Serializable::Unmapped` module is included, unknown properties in the YAML
  # document will be stored in a `Hash(String, YAML::Any)`. On serialization, any keys inside yaml_unmapped
  # will be serialized appended to the current yaml object.
  # ```
  # require "yaml"
  #
  # struct A
  #   include YAML::Serializable
  #   include YAML::Serializable::Unmapped
  #   @a : Int32
  # end
  #
  # a = A.from_yaml("---\na: 1\nb: 2\n") # => A(@yaml_unmapped={"b" => 2}, @a=1)
  # a.yaml_unmapped["b"].raw.class       # => Int64
  # a.to_yaml                            # => "---\na: 1\nb: 2\n"
  # ```
  #
  #
  # ### Class annotation `YAML::Serializable::Options`
  #
  # supported properties:
  # * **emit_nulls**: if `true`, emits a `null` value for all nilable properties (by default nulls are not emitted)
  #
  # ```
  # require "yaml"
  #
  # @[YAML::Serializable::Options(emit_nulls: true)]
  # class A
  #   include YAML::Serializable
  #   @a : Int32?
  # end
  # ```
  #
  # ### Discriminator field
  #
  # A very common YAML serialization strategy for handling different objects
  # under a same hierarchy is to use a discriminator field. For example in
  # [GeoJSON](https://tools.ietf.org/html/rfc7946) each object has a "type"
  # field, and the rest of the fields, and their meaning, depend on its value.
  #
  # You can use `YAML::Serializable.use_yaml_discriminator` for this use case.
  #
  # ### `after_initialize` method
  #
  # `#after_initialize` is a method that runs after an instance is deserialized
  # from YAML. It can be used as a hook to post-process the initialized object.
  #
  # Example:
  # ```
  # require "yaml"
  #
  # class Person
  #   include YAML::Serializable
  #   getter name : String
  #
  #   def after_initialize
  #     @name = @name.upcase
  #   end
  # end
  #
  # person = Person.from_yaml "---\nname: Jane\n"
  # person.name # => "JANE"
  # ```
  module Serializable
    annotation Options
    end

    macro included
      # Define a `new` directly in the included type,
      # so it overloads well with other possible initializes

      def self.new(ctx : ::YAML::ParseContext, node : ::YAML::Nodes::Node)
        new_from_yaml_node(ctx, node)
      end

      private def self.new_from_yaml_node(ctx : ::YAML::ParseContext, node : ::YAML::Nodes::Node)
        ctx.read_alias(node, self) do |obj|
          return obj
        end

        instance = allocate

        ctx.record_anchor(node, instance)

        instance.initialize(__context_for_yaml_serializable: ctx, __node_for_yaml_serializable: node)
        ::GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      # When the type is inherited, carry over the `new`
      # so it can compete with other possible initializes

      macro inherited
        def self.new(ctx : ::YAML::ParseContext, node : ::YAML::Nodes::Node)
          new_from_yaml_node(ctx, node)
        end
      end

      def initialize(*, __context_for_yaml_serializable ctx : ::YAML::ParseContext, __node_for_yaml_serializable node : ::YAML::Nodes::Node)
        {% verbatim do %}
          {% begin %}
            {% properties = {} of Nil => Nil %}
            {% for ivar in @type.instance_vars %}
              {% ann = ivar.annotation(::YAML::Field) %}
              {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
                {%
                  properties[ivar.id] = {
                    key:         ((ann && ann[:key]) || ivar).id.stringify,
                    has_default: ivar.has_default_value?,
                    default:     ivar.default_value,
                    nilable:     ivar.type.nilable?,
                    converter:   ann && ann[:converter],
                    presence:    ann && ann[:presence],
                  }
                %}
              {% end %}
            {% end %}

            # `%var`'s type must be exact to avoid type inference issues with
            # recursively defined serializable types
            {% for name, value in properties %}
              %var{name} = uninitialized ::Union(typeof(@{{ name }}))
              %found{name} = false
            {% end %}

            case node
            when ::YAML::Nodes::Mapping
              ::YAML::Schema::Core.each(node) do |key_node, value_node|
                unless key_node.is_a?(::YAML::Nodes::Scalar)
                  key_node.raise "Expected scalar as key for mapping"
                end

                key = key_node.value

                case key
                {% for name, value in properties %}
                  when {{ value[:key] }}
                    begin
                      {% if value[:has_default] || value[:nilable] %}
                        if ::YAML::Schema::Core.parse_null?(value_node)
                          {% if value[:nilable] %}
                            %var{name} = nil
                            %found{name} = true
                          {% end %}
                          next
                        end
                      {% end %}

                      %var{name} =
                        {% if value[:converter] %}
                          {{ value[:converter] }}.from_yaml(ctx, value_node)
                        {% else %}
                          ::Union(typeof(@{{ name }})).new(ctx, value_node)
                        {% end %}
                      %found{name} = true
                    end
                {% end %}
                else
                  on_unknown_yaml_attribute(ctx, key, key_node, value_node)
                end
              end
            when ::YAML::Nodes::Scalar
              if node.value.empty? && node.style.plain? && !node.tag
                # We consider an empty scalar as an empty mapping
              else
                node.raise "Expected mapping, not #{node.class}"
              end
            else
              node.raise "Expected mapping, not #{node.class}"
            end

            {% for name, value in properties %}
              if %found{name}
                @{{ name }} = %var{name}
              else
                {% unless value[:has_default] || value[:nilable] %}
                  node.raise "Missing YAML attribute: {{ value[:key].id }}"
                {% end %}
              end

              {% if value[:presence] %}
                @{{ name }}_present = %found{name}
              {% end %}
            {% end %}
          {% end %}
        {% end %}
        after_initialize
      end
    end

    protected def after_initialize
    end

    protected def on_unknown_yaml_attribute(ctx, key, key_node, value_node)
    end

    protected def on_to_yaml(yaml : ::YAML::Nodes::Builder)
    end

    def to_yaml(yaml : ::YAML::Nodes::Builder)
      {% begin %}
        {% options = @type.annotation(::YAML::Serializable::Options) %}
        {% emit_nulls = options && options[:emit_nulls] %}

        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::YAML::Field) %}
          {% unless ann && (ann[:ignore] || ann[:ignore_serialize] == true) %}
            {%
              properties[ivar.id] = {
                key:              ((ann && ann[:key]) || ivar).id.stringify,
                converter:        ann && ann[:converter],
                emit_null:        (ann && (ann[:emit_null] != nil) ? ann[:emit_null] : emit_nulls),
                ignore_serialize: ann && ann[:ignore_serialize],
              }
            %}
          {% end %}
        {% end %}

        yaml.mapping(reference: self) do
          {% for name, value in properties %}
            _{{ name }} = @{{ name }}

            {% if value[:ignore_serialize] %}
              unless {{ value[:ignore_serialize] }}
            {% end %}

              {% unless value[:emit_null] %}
                unless _{{ name }}.nil?
              {% end %}

                {{ value[:key] }}.to_yaml(yaml)

                {% if value[:converter] %}
                  if _{{ name }}
                    {{ value[:converter] }}.to_yaml(_{{ name }}, yaml)
                  else
                    nil.to_yaml(yaml)
                  end
                {% else %}
                  _{{ name }}.to_yaml(yaml)
                {% end %}

              {% unless value[:emit_null] %}
                end
              {% end %}
            {% if value[:ignore_serialize] %}
              end
            {% end %}
          {% end %}
          on_to_yaml(yaml)
        end
      {% end %}
    end

    module Strict
      protected def on_unknown_yaml_attribute(ctx, key, key_node, value_node)
        key_node.raise "Unknown yaml attribute: #{key}"
      end
    end

    module Unmapped
      @[::YAML::Field(ignore: true)]
      property yaml_unmapped = Hash(String, ::YAML::Any).new

      protected def on_unknown_yaml_attribute(ctx, key, key_node, value_node)
        yaml_unmapped[key] = ::YAML::Any.new(ctx, value_node)
      end

      protected def on_to_yaml(yaml)
        yaml_unmapped.each do |key, value|
          key.to_yaml(yaml)
          value.to_yaml(yaml)
        end
      end
    end

    # Tells this class to decode YAML by using a field as a discriminator.
    #
    # - *field* must be the field name to use as a discriminator
    # - *mapping* must be a hash or named tuple where each key-value pair
    #   maps a discriminator value to a class to deserialize
    #
    # For example:
    #
    # ```
    # require "yaml"
    #
    # abstract class Shape
    #   include YAML::Serializable
    #
    #   use_yaml_discriminator "type", {point: Point, circle: Circle}
    #
    #   property type : String
    # end
    #
    # class Point < Shape
    #   property x : Int32
    #   property y : Int32
    # end
    #
    # class Circle < Shape
    #   property x : Int32
    #   property y : Int32
    #   property radius : Int32
    # end
    #
    # Shape.from_yaml(%(
    #   type: point
    #   x: 1
    #   y: 2
    # )) # => #<Point:0x10373ae20 @type="point", @x=1, @y=2>
    #
    # Shape.from_yaml(%(
    #   type: circle
    #   x: 1
    #   y: 2
    #   radius: 3
    # )) # => #<Circle:0x106a4cea0 @type="circle", @x=1, @y=2, @radius=3>
    # ```
    macro use_yaml_discriminator(field, mapping)
      {% unless mapping.is_a?(HashLiteral) || mapping.is_a?(NamedTupleLiteral) %}
        {% mapping.raise "Mapping argument must be a HashLiteral or a NamedTupleLiteral, not #{mapping.class_name.id}" %}
      {% end %}

      def self.new(ctx : ::YAML::ParseContext, node : ::YAML::Nodes::Node)
        ctx.read_alias(node, \{{@type}}) do |obj|
          return obj
        end

        unless node.is_a?(::YAML::Nodes::Mapping)
          node.raise "Expected YAML mapping, not #{node.class}"
        end

        node.each do |key, value|
          next unless key.is_a?(::YAML::Nodes::Scalar) && value.is_a?(::YAML::Nodes::Scalar)
          next unless key.value == {{ field.id.stringify }}

          discriminator_value = value.value
          case discriminator_value
          {% for key, value in mapping %}
            {% if key.is_a?(Path) %}
              {% key = key.resolve %}
            {% end %}
            {% if key.is_a?(NumberLiteral) %}
              # An enum value is always a typed NumberLiteral and stringifies with type
              # suffix unless it's Int32.
              # TODO: Replace this workaround with NumberLiteral#to_number after the next release
              {% key = key.id.split("_")[0] %}
            {% end %}
            when {{ key.id.stringify }}
              return {{ value.id }}.new(ctx, node)
          {% end %}
          else
            node.raise "Unknown '{{ field.id }}' discriminator value: #{discriminator_value.inspect}"
          end
        end

        node.raise "Missing YAML discriminator field '{{ field.id }}'"
      end
    end
  end
end
