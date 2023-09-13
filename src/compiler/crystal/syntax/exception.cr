require "../exception"

module Crystal
  class SyntaxException < CodeError
    include ErrorFormat

    getter line_number : Int32
    getter column_number : Int32
    getter filename
    getter size : Int32?

    def initialize(message, @line_number, @column_number, @filename, @size = nil)
      super(message)
    end

    def has_location?
      @filename || @line_number
    end

    def to_json_single(json)
      json.object do
        json.field "file", true_filename
        json.field "line", @line_number
        json.field "column", @column_number
        json.field "size", @size
        json.field "message", @message
      end
    end

    def append_to_s(io : IO, source)
      msg = @message.to_s
      error_message_lines = msg.lines

      io << error_body(source, default_message)
      io << '\n'
      io << colorize("#{@warning ? "Warning" : "Error"}: #{error_message_lines.shift}").yellow.bold
      io << remaining error_message_lines
    end

    def default_message
      if (filename = @filename) && (line_number = @line_number)
        "#{@warning ? "warning" : "syntax error"} in #{filename}:#{line_number}"
      end
    end

    def to_s_with_source(io : IO, source)
      append_to_s io, source
    end

    def deepest_error_message
      @message
    end
  end
end
