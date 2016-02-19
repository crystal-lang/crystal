module DB
  # Represents a prepared query in a `Connection`.
  # It should be created by `QueryMethods`.
  #
  # ### Note to implementors
  #
  # 1. Subclass `Statements`
  # 2. `Statements` are created from a custom driver `Connection#prepare` method.
  # 3. `#perform_query` executes a query that is expected to return a `ResultSet`
  # 4. `#perform_exec` executes a query that is expected to return an `ExecResult`
  # 6. `#do_close` is called to release the statement resources.
  abstract class Statement
    include Disposable

    # :nodoc:
    getter connection

    def initialize(@connection)
    end

    protected def do_close
    end

    def release_connection
      @connection.database.return_to_pool(@connection)
    end

    # See `QueryMethods#exec`
    def exec
      perform_exec_and_release(Slice(Any).new(0)) # no overload matches ... with types Slice(NoReturn)
    end

    # See `QueryMethods#exec`
    def exec(args : Enumerable(Any))
      perform_exec_and_release(args.to_a.to_unsafe.to_slice(args.size))
    end

    # See `QueryMethods#exec`
    def exec(*args)
      # TODO better way to do it
      perform_exec_and_release(args.to_a.to_unsafe.to_slice(args.size))
    end

    # See `QueryMethods#scalar`
    def scalar(*args)
      query(*args) do |rs|
        rs.each do
          # return case rs.read?(rs.column_type(0)) # :-( Some day...
          case rs.column_type(0)
          when String.class
            return rs.read?(String)
          when Int32.class
            return rs.read?(Int32)
          when Int64.class
            return rs.read?(Int64)
          when Float32.class
            return rs.read?(Float32)
          when Float64.class
            return rs.read?(Float64)
          when Slice(UInt8).class
            return rs.read?(Slice(UInt8))
          when Nil.class
            return rs.read?(Int32)
          else
            raise "not implemented for #{rs.column_type(0)} type"
          end
        end
      end

      raise "no results"
    end

    # See `QueryMethods#query`
    def query(*args)
      perform_query *args
    end

    # See `QueryMethods#query`
    def query(*args)
      perform_query(*args).tap do |rs|
        begin
          yield rs
        ensure
          rs.close
        end
      end
    end

    private def perform_query : ResultSet
      perform_query(Slice(Any).new(0)) # no overload matches ... with types Slice(NoReturn)
    end

    private def perform_query(args : Enumerable(Any)) : ResultSet
      # TODO better way to do it
      perform_query(args.to_a.to_unsafe.to_slice(args.size))
    end

    private def perform_query(*args) : ResultSet
      # TODO better way to do it
      perform_query(args.to_a.to_unsafe.to_slice(args.size))
    end

    private def perform_exec_and_release(args : Slice(Any)) : ExecResult
      perform_exec(args).tap do
        release_connection
      end
    end

    protected abstract def perform_query(args : Slice(Any)) : ResultSet
    protected abstract def perform_exec(args : Slice(Any)) : ExecResult
  end
end
