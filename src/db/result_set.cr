module DB
  # The response of a query performed on a `Database`.
  #
  # See `DB` for a complete sample.
  #
  # Each `#read` call consumes the result and moves to the next column.
  #
  # ### Note to implementors
  #
  # 1. Override `#move_next` to move to the next row.
  # 2. Override `#read?(t)` for all `t` in `DB::TYPES`.
  # 3. (Optional) Override `#read(t)` for all `t` in `DB::TYPES`.
  # 4. Override `#column_count`, `#column_name`.
  # 5. Override `#column_type`. It must return a type in `DB::TYPES`.
  abstract class ResultSet
    # :nodoc:
    getter statement

    def initialize(@statement : Statement)
    end

    # Iterates over all the rows
    def each
      while move_next
        yield
      end
    end

    # Closes the result set.
    def close
      @statement.close
    end

    # Ensures it executes the query
    def exec
      move_next
    end

    # Move the next row in the result.
    # Return `false` if no more rows are available.
    # See `#each`
    abstract def move_next : Bool

    # TODO def empty? : Bool, handle internally with move_next (?)

    # Returns the number of columns in the result
    abstract def column_count : Int32

    # Returns the name of the column in `index` 0-based position.
    abstract def column_name(index : Int32) : String

    # Returns the type of the column in `index` 0-based position.
    # The result is one of `DB::TYPES`.
    abstract def column_type(index : Int32)

    # list datatypes that must be supported form the driver
    # users will call read(String) or read?(String) for nillables

    {% for t in DB::TYPES %}
      # Reads the next column as a nillable {{t}}.
      abstract def read?(t : {{t}}.class) : {{t}}?

      # Reads the next column as a {{t}}.
      def read(t : {{t}}.class) : {{t}}
        read?({{t}}).not_nil!
      end
    {% end %}
  end
end
