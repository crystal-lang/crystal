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
    getter connection

    def initialize(@connection)
      @closed = false
    end

    # See `QueryMethods#exec`
    def exec
      perform_exec(Slice(Any).new(0)) # no overload matches ... with types Slice(NoReturn)
    end

    # See `QueryMethods#exec`
    def exec(*args)
      # TODO better way to do it
      perform_exec(args.to_a.to_unsafe.to_slice(args.size))
    end

    # See `QueryMethods#scalar`
    def scalar(*args)
      query(*args) do |rs|
        rs.each do
          # return case rs.read?(rs.column_type(0)) # :-( Some day...
          t = rs.column_type(0)
          if t == String
            return rs.read?(String)
          elsif t == Int32
            return rs.read?(Int32)
          elsif t == Int64
            return rs.read?(Int64)
          elsif t == Float32
            return rs.read?(Float32)
          elsif t == Float64
            return rs.read?(Float64)
          elsif t == Slice(UInt8)
            return rs.read?(Slice(UInt8))
          elsif t == Nil
            return rs.read?(Int32)
          else
            raise "not implemented for #{t} type"
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

    private def perform_query(*args) : ResultSet
      # TODO better way to do it
      perform_query(args.to_a.to_unsafe.to_slice(args.size))
    end

    # Closes this statement.
    def close
      return if @closed # make it work if closed
      @closed = true
      do_close
    end

    # Returns `true` if this statement is closed. See `#close`.
    def closed?
      @closed
    end

    # :nodoc:
    def finalize
      close
    end

    protected abstract def perform_query(args : Slice(Any)) : ResultSet
    protected abstract def perform_exec(args : Slice(Any)) : ExecResult

    protected def do_close
    end
  end
end
