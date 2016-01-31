module DB
  abstract class Connection
    getter connection_string

    def initialize(@connection_string)
      @closed = false
    end

    # Closes this connection.
    def close
      raise "Connection already closed" if @closed
      @closed = true
      perform_close
    end

    # Returns `true` if this statement is closed. See `#close`.
    def closed?
      @closed
    end

    # # :nodoc:
    # def finalize
    #   close unless closed?
    # end

    abstract def prepare(query) : Statement

    include QueryMethods

    abstract def last_insert_id : Int64

    protected abstract def perform_close
  end
end
