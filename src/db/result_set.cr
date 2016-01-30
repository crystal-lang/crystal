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

    def close
      @statement.close
    end

    abstract def move_next : Bool

    abstract def column_count : Int32
    abstract def column_name(index : Int32) : String

    # abstract def column_type(index : Int32)

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
