require "../exception"

module Crystal
  class SyntaxException < Exception
    include ErrorFormat

    getter line_number : Int32
    getter column_number : Int32
    getter filename
    getter size : Int32?

    def initialize(message, @line_number, @column_number, @filename, @size = nil)
      super(message)
    end

    def color=(color)
      @color = !!color
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

    def append_to_s(source, io)
      msg = @message.to_s
      error_message_lines = msg.lines
      default_message = "syntax error in #{@filename}:#{@line_number}"

      io << error_body(source, default_message)
      io << '\n'
      io << colorize("Error: #{error_message_lines.shift}").yellow.bold
      io << remaining error_message_lines
    end

    def to_s_with_source(source, io)
      append_to_s source, io
    end

    def deepest_error_message
      @message
    end
  end
end
