module DB
  abstract class Statement
    getter connection

    def initialize(@connection)
      @closed = false
    end

    def exec(*args)
      query(*args) do |rs|
        rs.exec
      end
    end

    def scalar(*args)
      scalar(Int32, *args)
    end

    # t in DB::TYPES
    def scalar(t, *args)
      query(*args) do |rs|
        rs.each do
          return rs.read(t)
        end
      end

      raise "unreachable"
    end

    def scalar?(*args)
      scalar?(Int32, *args)
    end

    # t in DB::TYPES
    def scalar?(t, *args)
      query(*args) do |rs|
        rs.each do
          return rs.read?(t)
        end
      end

      raise "unreachable"
    end

    def query(*args)
      execute *args
    end

    def query(*args)
      execute(*args).tap do |rs|
        begin
          yield rs
        ensure
          rs.close
        end
      end
    end

    private def execute(*args) : ResultSet
      execute args
    end

    private def execute(arg : Slice(UInt8))
      begin_parameters
      add_parameter 1, arg
      perform
    end

    private def execute(args : Enumerable)
      begin_parameters
      args.each_with_index(1) do |arg, index|
        if arg.is_a?(Hash)
          arg.each do |key, value|
            add_parameter key.to_s, value
          end
        else
          add_parameter index, arg
        end
      end
      perform
    end

    # Closes this statement.
    def close
      raise "Statement already closed" if @closed
      @closed = true
      on_close
    end

    # Returns `true` if this statement is closed. See `#close`.
    def closed?
      @closed
    end

    # 1-based positional arguments
    protected def begin_parameters
    end
    protected abstract def add_parameter(index : Int32, value)
    protected abstract def add_parameter(name : String, value)

    protected abstract def perform : ResultSet
    protected def on_close
    end
  end
end
