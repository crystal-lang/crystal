module DB
  abstract class Statement
    getter driver

    def initialize(@driver)
    end

    def exec(*args) : ResultSet
      exec args
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

    # 1-based positional arguments
    protected abstract def add_parameter(index : Int32, value)
    protected abstract def add_parameter(name : String, value)
    protected abstract def execute : ResultSet
  end
end
