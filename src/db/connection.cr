module DB
  # Database driver implementors must subclass `Connection`.
  #
  # Represents one active connection to a database.
  #
  # Users should never instantiate a `Connection` manually. Use `DB#open` or `Database#connection`.
  #
  # Refer to `QueryMethods` for documentation about querying the database through this connection.
  #
  # ### Note to implementors
  #
  # The connection must be initialized in `#initialize` and closed in `#perform_close`.
  #
  # To allow quering override `#prepare` method in order to return a prepared `Statement`.
  # Also override `#last_insert_id` to allow safe access to the last inserted id through this connection.
  #
  abstract class Connection
    # TODO add IDLE status, for connection ppool management.

    @closed = false

    # Closes this connection.
    def close
      raise "Connection already closed" if @closed # TODO make it no fail if closed
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

    # Returns an `Statement` with the prepared `query`
    abstract def prepare(query) : Statement

    include QueryMethods

    protected abstract def perform_close # TODO do_close
  end
end
