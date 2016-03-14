module DB
  # The response of a query performed on a `Database`.
  #
  # See `DB` for a complete sample.
  #
  # Each `#read` call consumes the result and moves to the next column.
  # Each column must be read in order.
  # At any moment a `#move_next` can be invoked, meaning to skip the
  # remaining, or even all the columns, in the current row.
  # Also it is not mandatory to consume the whole `ResultSet`, hence an iteration
  # through `#each` or `#move_next` can be stopped.
  #
  # **Note:** depending on how the `ResultSet` was obtained it might be mandatory an
  # explicit call to `#close`. Check `QueryMethods#query`.
  #
  # ### Note to implementors
  #
  # 1. Override `#move_next` to move to the next row.
  # 2. Override `#read?(t)` for all `t` in `DB::TYPES`.
  # 3. (Optional) Override `#read(t)` for all `t` in `DB::TYPES`.
  # 4. Override `#column_count`, `#column_name`.
  # 5. Override `#column_type`. It must return a type in `DB::TYPES`.
  abstract class ResultSet
    include Disposable

    # :nodoc:
    getter statement

    def initialize(@statement : DB::Statement)
    end

    protected def do_close
      statement.release_connection
    end

    # TODO add_next_result_set : Bool

    # Iterates over all the rows
    def each
      while move_next
        yield
      end
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

    # def read_blob
    #   yield ... io ....
    # end

    # def read_text
    #   yield ... io ....
    # end
  end
end
