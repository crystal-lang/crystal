require "macros/virtual_file"
require "colorize"

module Crystal
  abstract class Exception < ::Exception
    def to_s(io)
      to_s_with_source(nil, io)
    end

    def to_s_with_source(source)
      String.build do |io|
        to_s_with_source source, io
      end
    end
  end

  class SyntaxException < Exception
    getter line_number
    getter column_number
    getter filename
    getter length

    def initialize(message, @line_number, @column_number, @filename, @length = nil)
      super(message)
    end

    def has_location?
      @filename || @line
    end

    def append_to_s(source, io)
      if @filename
        io << "Syntax error in #{@filename}:#{@line_number}: #{@message.colorize.bold}"
      else
        io << "Syntax error in line #{@line_number}: #{@message.colorize.bold}"
      end

      source = fetch_source(source)

      if source
        lines = source.lines
        if @line_number - 1 < lines.length
          line = lines[@line_number - 1]
          if line
            io << "\n\n"
            io << line.chomp
            io << "\n"
            (@column_number - 1).times do
              io << " "
            end
            with_color.green.bold.surround(io) do
              io << "^"
              if length = @length
                io << ("~" * (length - 1))
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
        source = File.read(filename) if File.exists?(filename)
      when VirtualFile
        source = filename.source
      end
      source
    end

    def deepest_error_message
      @message
    end
  end

  class TypeException < Exception
    getter :node
    getter :inner

    def self.for_node(node, message, inner = nil)
      location = node.location
      if location
        column_number = node.name_column_number
        name_length = node.name_length
        if column_number == 0
          name_length = 0
          column_number = location.column_number
        end
        new message, location.line_number, column_number, location.filename, name_length, inner
      else
        new message, nil, 0, nil, 0, inner
      end
    end

    def initialize(message, @line, @column : Int32, @filename, @length = nil, @inner = nil)
      super(message)
    end

    def to_s_with_source(source, io)
      io << "Error "
      append_to_s source, io
    end

    def append_to_s(source, io)
      inner = @inner
      filename = @filename

      # If the inner exception has no location it means that they came from virtual nodes.
      # In that case, get the deepest error message and only show that.
      if inner && !inner.has_location?
        msg = deepest_error_message.to_s
      else
        msg = @message.to_s
      end

      is_macro = false

      case filename
      when String
        if File.exists?(filename)
          lines = File.read_lines(filename)
          io << "in " << filename << ":" << @line << ": "
          append_error_message io, msg
        else
          lines = source ? source.lines.to_a : nil
          io << "in line #{@line}: " if @line
          append_error_message io, msg
        end
      when VirtualFile
        lines = filename.source.lines.to_a
        io << "in macro '#{filename.macro.name}' #{filename.macro.location.try &.filename}:#{filename.macro.location.try &.line_number}, line #{@line}:\n\n"
        io << lines.to_s_with_line_numbers
        is_macro = true
      else
        lines = source ? source.lines.to_a : nil
        io << "in line #{@line}: " if @line
        append_error_message io, msg
      end

      if lines && (line_number = @line) && (line = lines[line_number - 1]?)
        io << "\n\n"
        io << line.chomp
        io << "\n"
        io << (" " * (@column - 1))
        with_color.green.bold.surround(io) do
          io << "^"
          if @length && @length > 0
            io << ("~" * (@length - 1))
          end
        end
      end
      io << "\n"

      if is_macro
        io << "\n"
        append_error_message io, @message
      end

      if inner && inner.has_location?
        io << "\n"
        inner.append_to_s source, io
      end
    end

    def append_error_message(io, msg)
      if @inner
        io << msg
      else
        io << msg.colorize.bold
      end
    end

    def has_location?
      if @inner.try &.has_location?
        true
      else
        @filename || @line
      end
    end

    def deepest_error_message
      if inner = @inner
        inner.deepest_error_message
      else
        @message
      end
    end
  end

  class MethodTraceException < Exception
    def initialize(@owner, @trace)
      super(nil)
    end

    def has_location?
      true
    end

    def to_s_with_source(source, io)
      append_to_s(source, io)
    end

    def append_to_s(source, io)
      return unless @trace.length > 0

      io << ("=" * 80)
      io << "\n\n#{@owner} trace:"
      @trace.each do |node|
        location = node.location
        if location
          filename = location.filename
          next_trace = false
          case filename
          when VirtualFile
            lines = filename.source.lines.to_a
            filename = "macro #{filename.macro.name} (in #{filename.macro.location.try &.filename}:#{filename.macro.location.try &.line_number})"
          when String
            if File.exists?(filename)
              lines = File.read_lines filename
            else
              lines = source ? source.lines.to_a : nil
            end
          else
            next_trace = true
          end

          unless next_trace
            line_number = location.line_number
            column_number = location.column_number

            io << "\n\n"
            io << "  "
            io << filename << ":" << line_number
            io << "\n\n"

            if lines
              line = lines[line_number - 1]

              name_column = node.name_column_number
              name_length = node.name_length

              io << "    "
              io << line.chomp
              io << "\n"
              if name_column > 0
                io << "    "
                io << (" " * (name_column - 1))
                io << "^"
                if name_length > 0
                  io << ("~" * (name_length - 1)) if name_length
                end
              end
            end
          end
        end
      end
    end

    def deepest_error_message
      nil
    end
  end

  class FrozenTypeException < TypeException
  end
end
