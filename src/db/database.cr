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
    getter driver_class

    # Connection configuration to the database.
    getter connection_string

    # :nodoc:
    def initialize(@driver_class, @connection_string)
      @driver = @driver_class.new(@connection_string)
      @connection = @driver.build_connection
    end

    # Closes all connection to the database.
    def close
      @connection.close
    end

    # :nodoc:
    def connection
      @connection
    end

    # :nodoc:
    def prepare(query)
      connection.prepare(query)
    end

    include QueryMethods
  end
end
