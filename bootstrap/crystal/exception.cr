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
            str << "\033[1;32m^\033[0m"
            str << "\n"
          end
        end
      end
    end

    def to_s(source = nil)
      filename = @filename

      String.build do |str|
        case filename
        when String
          source = File.read(filename) if File.exists?(filename)
        when VirtualFile
          source = filename.source
        end
        append_to_s str, source
        nil # TODO: remove this line
      end
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
        new message, 0, 0, nil, 0, inner
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

      if lines && @line
        line = lines[@line - 1]
        if line
          str << "\n\n"
          str << line.chomp
          str << "\n"
          str << (" " * (@column - 1))
          str << "\033[1;32m"
          str << "^"
          if @length && @length > 0
            str << ("~" * (@length - 1))
          end
          str << "\033[0m"
        end
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

  class FrozenTypeException < TypeException
  end
end
