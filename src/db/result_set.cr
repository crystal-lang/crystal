module DB
  abstract class ResultSet
    getter statement

    def initialize(@statement : Statement)
    end

    def each
      while move_next
        yield
      end
    end

    abstract def move_next : Bool

    # list datatypes that must be supported form the driver
    # users will call read(String) or read?(String) for nillables
    {% for t in DB::TYPES %}
      abstract def read?(t : {{t}}.class) : {{t}}?

      def read(t : {{t}}.class) : {{t}}
        read?({{t}}).not_nil!
      end
    {% end %}
  end
end
