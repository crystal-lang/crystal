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
    include Disposable

    # :nodoc:
    abstract def prepare(query) : Statement

    include QueryMethods
  end
end
