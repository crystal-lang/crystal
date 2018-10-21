require "./severity"

struct Logger
  struct Entry
    getter message : String
    getter severity : Severity
    getter component : String
    getter time : Time
    getter line_number : Int32
    getter filename : String

    def initialize(@message, @severity, @component, @time, @line_number, @filename)
    end
  end
end
