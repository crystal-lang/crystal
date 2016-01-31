module DB
  abstract class Driver
    getter connection_string

    def initialize(@connection_string : String)
    end

    abstract def build_connection : Connection
  end
end
