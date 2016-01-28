module DB
  abstract class ResultSet
    getter statement

    def initialize(@statement : Statement)
    end

    def each
      while has_next
        yield
      end
    end

    abstract def has_next : Bool

    # def read(t : T.class) : T
    # end

    # list datatypes that must be supported form the driver
    # implementors will override read_string
    # users will call read(String) due to overloads read(T) will be a T
    # TODO: unable to write unions (nillables)
    {% for t in [String, UInt64] %}
      def read(t : {{t}}.class) : {{t}}
        read_{{t.name.underscore}}
      end

      protected abstract def read_{{t.name.underscore}} : {{t}}
    {% end %}

    # def read(t : String.class) : String
    #   read_string
    # end
    #
    # protected abstract def read_string : String
  end
end
