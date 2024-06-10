require "uri"

require "./from_form_data"

module URI::Params::Serializable
  macro included
    def self.from_form_data(params : ::URI::Params)
      new_from_form_data(params)
    end

    # :nodoc:
    #
    # This is needed so that nested types can pass the name thru internally.
    # Has to be public so the generated code can call it, but should be considered an implementation detail.
    def self.from_form_data(params : ::URI::Params, name : String)
      new_from_form_data(params, name)
    end

    protected def self.new_from_form_data(params : ::URI::Params, name : String? = nil)
      instance = allocate
      instance.initialize(__uri_params: params, name: name)
      GC.add_finalizer(instance) if instance.responds_to?(:finalize)
      instance
    end

    macro inherited
      def self.from_form_data(params : ::URI::Params)
        new_from_form_data(params)
      end

      # :nodoc:
      def self.from_form_data(params : ::URI::Params, name : String)
        new_from_form_data(params, name)
      end
    end
  end

  # :nodoc:
  def initialize(*, __uri_params params : ::URI::Params, name : String?)
    {% begin %}
      {% for ivar, idx in @type.instance_vars %}
        %name{idx} = name.nil? ? {{ivar.name.stringify}} : "#{name}[#{{{ivar.name.stringify}}}]"

        if v = {{ivar.type}}.from_form_data(params, %name{idx})
          @{{ivar.name.id}} = v
        else
          {% unless ivar.type.resolve.nilable? || ivar.has_default_value? %}
            raise URI::SerializableError.new "Missing required property: '#{%name{idx}}'."
          {% end %}
        end
      {% end %}
    {% end %}
  end
end

class URI::SerializableError < URI::Error
end
