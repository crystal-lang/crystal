module DB
  # Methods to allow querying a database.
  # All methods accepts a `query : String` and a set arguments.
  #
  # Three kind of statements can be performed:
  #  1. `#exec` waits no record response from the database. An `ExecResult` is returned.
  #  2. `#scalar` reads a single value of the response. A `DB::Any` is returned.
  #  3. `#query` returns a `ResultSet` that allows iteration over the rows in the response and column information.
  #
  # Arguments can be passed by position
  #
  # ```
  # db.query("SELECT name FROM ... WHERE age > ?", age)
  # ```
  #
  # Convention of mapping how arguments are mapped to the query depends on each driver.
  #
  # Including `QueryMethods` requires a `prepare(query) : Statement` method.
  module QueryMethods
    abstract def prepare(query) : Statement

    # Returns a `ResultSet` for the `query`.
    # The `ResultSet` must be closed manually.
    def query(query, *args)
      prepare(query).query(*args)
    end

    # Yields a `ResultSet` for the `query`.
    # The `ResultSet` is closed automatically.
    def query(query, *args)
      # CHECK prepare(query).query(*args, &block)
      query(query, *args).tap do |rs|
        begin
          yield rs
        ensure
          rs.close
        end
      end
    end

    # Performs the `query` discarding any response
    def exec(query, *args)
      prepare(query).exec(*args)
    end

    # Performs the `query` and returns a single scalar `DB::Any` value
    # puts db.scalar("SELECT MAX(name)") as String # => (a String)
    def scalar(query, *args)
      prepare(query).scalar(*args)
    end

    # TODO add query_row
  end
end
