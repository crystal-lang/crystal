module DB
  # Acts as an entry point for database access.
  # Currently it creates a single connection to the database.
  # Eventually a connection pool will be handled.
  #
  # It should be created from DB module. See `DB#open`.
  #
  # Refer to `QueryMethods` for documentation about querying the database.
  class Database
    # :nodoc:
    getter driver

    # Returns the uri with the connection settings to the database
    getter uri

    # :nodoc:
    def initialize(@driver, @uri)
      @in_pool = true
      @connection = @driver.build_connection(self)
    end

    # Closes all connection to the database.
    def close
      @connection.try &.close
    end

    # :nodoc:
    def prepare(query)
      get_from_pool.prepare(query)
    end

    # :nodoc:
    def get_from_pool
      raise "DB Pool Exhausted" unless @in_pool
      @in_pool = false
      @connection.not_nil!
    end

    # :nodoc:
    def return_to_pool(connection)
      @in_pool = true
    end

    include QueryMethods
  end
end
