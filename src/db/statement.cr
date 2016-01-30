module DB
  abstract class Statement
    getter driver

    def initialize(@driver)
      @closed = false
    end

    def exec(*args) : ResultSet
      exec args
    end

    def exec(arg : Slice(UInt8))
      before_execute
      add_parameter 1, arg
      execute
    end

    def exec(args : Enumerable)
      before_execute
      args.each_with_index(1) do |arg, index|
        if arg.is_a?(Hash)
          arg.each do |key, value|
            add_parameter key.to_s, value
          end
        else
          add_parameter index, arg
        end
      end
      execute
    end

    protected def before_execute
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
    protected abstract def add_parameter(index : Int32, value)
    protected abstract def add_parameter(name : String, value)

    protected abstract def execute : ResultSet
    protected def on_close
    end
  end
end
