require "../exception"

module Crystal
  class SyntaxException < Exception
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

    def append_to_s(source, io)
      if @filename
        io << "Syntax error in #{relative_filename(@filename)}:#{@line_number}: #{colorize(@message).bold}"
      else
        io << "Syntax error in line #{@line_number}: #{colorize(@message).bold}"
      end

      source = fetch_source(source)

      if source
        lines = source.lines
        if @line_number - 1 < lines.size
          line = lines[@line_number - 1]
          if line
            io << "\n\n"
            io << replace_leading_tabs_with_spaces(line.chomp)
            io << "\n"
            (@column_number - 1).times do
              io << " "
            end
            with_color.green.bold.surround(io) do
              io << "^"
              if size = @size
                io << ("~" * (size - 1))
              end
            end
            io << "\n"
          end
        end
      end
    end

    def to_s_with_source(source, io)
      append_to_s fetch_source(source), io
    end

    def fetch_source(source)
      case filename = @filename
      when String
        source = File.read(filename) if File.file?(filename)
      when VirtualFile
        source = filename.source
      end
      source
    end

    def deepest_error_message
      @message
    end
  end
end
