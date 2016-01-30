module DB
  # Acts as an entry point for database access.
  # Currently it creates a single connection to the database.
  # Eventually a connection pool will be handled.
  #
  # It should be created from DB module. See `DB.open`.
  class Database
    getter driver_class
    getter options

    def initialize(@driver_class, @options)
      @driver = @driver_class.new(@options)
      @connection = @driver.build_connection
    end

    # Closes all connection to the database
    def close
      @connection.close
    end

    # Returns a `Connection` to the database
    def connection
      @connection
    end

    # Prepares a `Statement`. The Statement must be closed explicitly
    # after is not longer in use.
    #
    # Usually `#exec`, `#query` or `#scalar` should be used.
    def prepare(query)
      connection.prepare(query)
    end

    def query(query, *args)
      prepare(query).query(*args)
    end

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

    def exec(query, *args)
      prepare(query).exec(*args)
    end

    def scalar(query, *args)
      prepare(query).scalar(*args)
    end

    def scalar(t, query, *args)
      prepare(query).scalar(t, *args)
    end

    def scalar?(query, *args)
      prepare(query).scalar?(*args)
    end

    def scalar?(t, query, *args)
      prepare(query).scalar?(t, *args)
    end
  end
end
