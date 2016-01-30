module DB
  abstract class Driver
    getter options

    def initialize(@options)
    end

    abstract def build_connection : Connection
  end
end
