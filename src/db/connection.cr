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
  # The connection must be initialized in `#initialize` and closed in `#do_close`.
  #
  # Override `#build_statement` method in order to return a prepared `Statement` to allow querying.
  # See also `Statement` to define how the statements are executed.
  #
  abstract class Connection
    include Disposable
    include QueryMethods

    # :nodoc:
    getter database
    @statements_cache = {} of String => Statement

    def initialize(@database : Database)
    end

    # :nodoc:
    def prepare(query) : Statement
      stmt = @statements_cache.fetch(query, nil)
      if stmt.is_a?(Nil)
        stmt = build_statement(query)
        @statements_cache[query] = stmt
      end

      stmt
    end

    abstract def build_statement(query) : Statement

    protected def do_close
      @statements_cache.clear
    end
  end
end
