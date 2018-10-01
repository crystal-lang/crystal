require "./severity"

class Logger
  class Entry
    getter severity : Severity
    getter component : String
    getter time : Time
    getter line_number : Int32
    getter filename : String
    @message : String | Proc(String)

    def initialize(@message, @severity, @component, @time, @line_number, @filename)
    end

    def message : String
      if (msg = @message).is_a? Proc(String)
        return @message = msg.call
      else
        return msg
      end
    end
  end
end
