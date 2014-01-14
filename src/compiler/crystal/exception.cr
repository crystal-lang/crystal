require "virtual_file"

module Crystal
  abstract class Exception < ::Exception
  end

  class SyntaxException < Exception
    def initialize(message, @line_number, @column_number, @filename)
      super(message)
    end

    def has_location?
      @filename || @line
    end

    def append_to_s(str, source)
      if @filename
        str << "Syntax error in #{@filename}:#{@line_number}: #{@message}"
      else
        str << "Syntax error in line #{@line_number}: #{@message}"
      end

      source = fetch_source(source)

      if source
        lines = source.lines
        if @line_number - 1 < lines.length
          line = lines[@line_number - 1]
          if line
            str << "\n\n"
            str << line.chomp
            str << "\n"
            (@column_number - 1).times do
              str << " "
            end
            str << "\e[1;32m"
            str << "^"
            str << "\e[0m"
            str << "\n"
          end
        end
      end
    end

    def to_s(source = nil)
      String.build do |str|
        append_to_s str, fetch_source(source)
        nil # TODO: remove this line
      end
    end

    def fetch_source(source)
      filename = @filename
      case filename
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
        new message, location.line_number, (node.name_column_number || location.column_number), location.filename, (node.name_length || 0), inner
      else
        new message, nil, 0, nil, 0, inner
      end
    end

    def initialize(message, @line, @column : Int32, @filename, @length = nil, @inner = nil)
      super(message)
    end

    def to_s(source = nil)
      String.build do |str|
        str << "Error "
        append_to_s(str, source)
      end
    end

    def append_to_s(str, source)
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
          str << "in #{filename}:#{@line}: #{msg}"
        else
          lines = source ? source.lines.to_a : nil
          str << "in line #{@line}: " if @line
          str << msg
        end
      when VirtualFile
        lines = filename.source.lines.to_a
        str << "in macro '#{filename.macro.name}' #{filename.macro.location.try &.filename}:#{filename.macro.location.try &.line_number}, line #{@line}:\n\n"
        str << lines.to_s_with_line_numbers
        is_macro = true
      else
        lines = source ? source.lines.to_a : nil
        str << "in line #{@line}: " if @line
        str << msg
      end

      if lines && @line && (line = lines[@line - 1]?)
        str << "\n\n"
        str << line.chomp
        str << "\n"
        str << (" " * (@column - 1))
        str << "\e[1;32m"
        str << "^"
        if @length && @length > 0
          str << ("~" * (@length - 1))
        end
        str << "\e[0m"
      end
      str << "\n"

      if is_macro
        str << "\n"
        str << @message.to_s
      end

      if inner && inner.has_location?
        str << "\n"
        inner.append_to_s(str, source)
      end
    end

    def has_location?
      if @inner && @inner.has_location?
        true
      else
        @filename || @line
      end
    end

    def deepest_error_message
      if @inner
        @inner.deepest_error_message
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

    def to_s(source = nil)
      String.build do |str|
        append_to_s(str, source)
      end
    end

    def append_to_s(str, source)
      return unless @trace.length > 0

      str << ("=" * 80)
      str << "\n\n#{@owner} trace:"
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

            str << "\n\n"
            str << "  "
            str << filename
            str << ":"
            str << line_number
            str << "\n\n"

            if lines
              line = lines[line_number - 1]

              name_column = node.name_column_number
              name_length = node.name_length

              str << "    "
              str << line.chomp
              str << "\n"
              if name_column
                str << "    "
                str << (" " * (name_column - 1))
                str << "^"
                if name_length
                  str << ("~" * (name_length - 1)) if name_length
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
