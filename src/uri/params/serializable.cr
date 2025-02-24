require "uri"

require "./to_www_form"
require "./from_www_form"

struct URI::Params
  annotation Field; end

  # The `URI::Params::Serializable` module automatically generates methods for `x-www-form-urlencoded` serialization when included.
  #
  # NOTE: To use this module, you must explicitly import it with `require "uri/params/serializable"`.
  #
  # ### Example
  #
  # ```
  # require "uri/params/serializable"
  #
  # struct Applicant
  #   include URI::Params::Serializable
  #
  #   getter first_name : String
  #   getter last_name : String
  #   getter qualities : Array(String)
  # end
  #
  # applicant = Applicant.from_www_form "first_name=John&last_name=Doe&qualities=kind&qualities=smart"
  # applicant.first_name  # => "John"
  # applicant.last_name   # => "Doe"
  # applicant.qualities   # => ["kind", "smart"]
  # applicant.to_www_form # => "first_name=John&last_name=Doe&qualities=kind&qualities=smart"
  # ```
  #
  # ### Usage
  #
  # Including `URI::Params::Serializable` will create `#to_www_form` and `self.from_www_form` methods on the current class.
  # By default, these methods serialize into a www form encoded string containing the value of every instance variable, the keys being the instance variable name.
  # Union types are also supported, including unions with nil.
  # If multiple types in a union parse correctly, it is undefined which one will be chosen.
  #
  # To change how individual instance variables are parsed, the annotation `URI::Params::Field` can be placed on the instance variable.
  # Annotating property, getter and setter macros is also allowed.
  #
  # `URI::Params::Field` properties:
  # * **converter**: specify an alternate type for parsing. The converter must define `.from_www_form(params : URI::Params, name : String)`.
  # An example use case would be customizing the format when parsing `Time` instances, or supporting a type not natively supported.
  #
  # Deserialization also respects default values of variables:
  # ```
  # require "uri/params/serializable"
  #
  # struct A
  #   include URI::Params::Serializable
  #
  #   @a : Int32
  #   @b : Float64 = 1.0
  # end
  #
  # A.from_www_form("a=1") # => A(@a=1, @b=1.0)
  # ```
  module Serializable
    macro included
      def self.from_www_form(params : ::String)
        new_from_www_form ::URI::Params.parse params
      end

      # :nodoc:
      #
      # This is needed so that nested types can pass the name thru internally.
      # Has to be public so the generated code can call it, but should be considered an implementation detail.
      def self.from_www_form(params : ::URI::Params, name : ::String)
        new_from_www_form(params, name)
      end

      protected def self.new_from_www_form(params : ::URI::Params, name : ::String? = nil)
        instance = allocate
        instance.initialize(__uri_params: params, name: name)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      macro inherited
        def self.from_www_form(params : ::String)
          new_from_www_form ::URI::Params.parse params
        end

        # :nodoc:
        def self.from_www_form(params : ::URI::Params, name : ::String)
          new_from_www_form(params, name)
        end
      end
    end

    # :nodoc:
    def initialize(*, __uri_params params : ::URI::Params, name : String?)
      {% begin %}
        {% for ivar, idx in @type.instance_vars %}
          %name{idx} = name.nil? ? {{ivar.name.stringify}} : "#{name}[#{{{ivar.name.stringify}}}]"
          %value{idx} = {{(ann = ivar.annotation(URI::Params::Field)) && (converter = ann["converter"]) ? converter : ivar.type}}.from_www_form params, %name{idx}

          unless %value{idx}.nil?
            @{{ivar.name.id}} = %value{idx}
          else
            {% unless ivar.type.resolve.nilable? || ivar.has_default_value? %}
              raise URI::SerializableError.new "Missing required property: '#{%name{idx}}'."
            {% end %}
          end
        {% end %}
      {% end %}
    end

    def to_www_form(*, space_to_plus : Bool = true) : String
      URI::Params.build(space_to_plus: space_to_plus) do |form|
        {% for ivar in @type.instance_vars %}
          @{{ivar.name.id}}.to_www_form form, {{ivar.name.stringify}}
        {% end %}
      end
    end

    # :nodoc:
    def to_www_form(builder : URI::Params::Builder, name : String)
      {% for ivar in @type.instance_vars %}
        @{{ivar.name.id}}.to_www_form builder, "#{name}[#{{{ivar.name.stringify}}}]"
      {% end %}
    end
  end
end

class URI::SerializableError < URI::Error
end
