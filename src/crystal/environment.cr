module Crystal
  # ```
  # require "crystal/environment"
  #
  # Crystal.env.name         # => "development"
  # Crystal.env.development? # => true
  # Crystal.env.production?  # => false
  # ```
  module Environment
    ENV_KEY     = "CRYSTAL_ENV"
    ENV_VALUES  = %i(development test staging production)
    ENV_DEFAULT = "development"

    extend self

    def to_s(io)
      io << {{ @type.name.stringify }}
    end

    {% for env in ENV_VALUES %}
      def {{ env.id }}?
        name == {{ env.id.stringify }}
      end
    {% end %}

    def name
      ENV[ENV_KEY]? || ENV_DEFAULT
    end

    def name=(env : String?)
      ENV[ENV_KEY] = env
    end
  end

  # See `Crystal::Environment`.
  def self.env
    Environment
  end
end
