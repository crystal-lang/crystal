module DB
  # Methods to allow querying a database.
  # All methods accepts a `query : String` and a set arguments.
  #
  # Three kind of statements can be performed:
  #  1. `#exec` waits no response from the database.
  #  2. `#scalar` reads a single value of the response. Use `#scalar?` if the response is nillable.
  #  3. `#query` returns a ResultSet that allows iteration over the rows in the response and column information.
  #
  # Arguments can be passed:
  #  * by position: `db.query("SELECT name FROM ... WHERE age > ?", age)`
  #  * by symbol: `db.query("SELECT name FROM ... WHERE age > :age", {age: age})`
  #  * by string: `db.query("SELECT name FROM ... WHERE age > :age", {"age": age})`
  #
  # Convention of mapping how arguments are mapped to the query depends on each driver.
  #
  # Including `QueryMethods` requires a `prepare(query) : Statement` method.
  module QueryMethods
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

    # Performs the `query` and returns a single scalar `Int32` value
    def scalar(query, *args)
      prepare(query).scalar(*args)
    end

    # TODO remove scalar?  make it always nillable. raise if 0-rows   raise +1-rows

    # Performs the `query` and returns a single scalar value of type `t`.
    # `t` must be any of the allowed `DB::Any` types.
    #
    # ```
    # puts db.scalar(String, "SELECT MAX(name)") # => (a String)
    # ```
    def scalar(t, query, *args)
      prepare(query).scalar(t, *args)
    end

    # Performs the `query` and returns a single scalar `Int32 | Nil` value
    def scalar?(query, *args)
      prepare(query).scalar?(*args)
    end

    # Performs the `query` and returns a single scalar value of type `t` or `Nil`.
    # `t` must be any of the allowed `DB::Any` types.
    #
    # ```
    # puts db.scalar?(String, "SELECT MAX(name)") # => (a String | Nil)
    # ```
    def scalar?(t, query, *args)
      prepare(query).scalar?(t, *args)
    end
  end
end
