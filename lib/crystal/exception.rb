module Crystal
  class Exception < StandardError
    def message(source = nil)
      to_s(source)
    end

    def self.name_column_and_length(node)
      if node.respond_to?(:name) && node.name.respond_to?(:length)
        length = node.respond_to?(:name_length) ? node.name_length : node.name.length
        if node.respond_to?(:name_column_number)
          [node.name_column_number, length]
        else
          [node.column_number, length]
        end
      else
        [node.column_number, nil]
      end
    end
  end

  class SyntaxException < Exception
    def initialize(message, line_number, column_number, filename)
      @message = message
      @line_number = line_number
      @column_number = column_number
      @filename = filename
    end

    def to_s(source = nil)
      if @filename
        str = "Syntax error in #{@filename}:#{@line_number}: #{@message}"
      else
        str = "Syntax error in line #{@line_number}: #{@message}"
      end

      if @filename
        if @filename.is_a?(VirtualFile)
          source = @filename.source
        elsif File.file?(@filename)
          source = File.read(@filename)
        end
      end

      if source
        lines = source.lines.to_a
        line = lines[@line_number - 1]
        if line
          str << "\n\n"
          str << line.chomp
          str << "\n"
          str << (' ' * (@column_number - 1))
          str << '^'
          str << "\n"
        end
      end
      str
    end
  end

  class TypeException < Exception
    attr_accessor :node
    attr_accessor :inner

    def self.for_node(node, message, inner = nil)
      name_column, name_length = Exception.name_column_and_length(node)
      new message, node.line_number, name_column, node.filename, name_length, inner
    end

    def initialize(message, line, column, filename, length = nil, inner = nil)
      @message = message
      @line = line
      @column = column
      @filename = filename
      @length = length
      @inner = inner
    end

    def to_s(source = nil)
      str = 'Error '
      append_to_s(str, source)
      str
    end

    def append_to_s(str, source)
      # If the inner exception has no location it means that they came from virtual nodes.
      # In that case, get the deepest error message and only show that.
      if inner && !inner.has_location?
        msg = deepest_error_message.to_s
      else
        msg = @message.to_s
      end

      if @filename && file_exists?(@filename)
        if @filename.is_a?(VirtualFile)
          lines = @filename.source.lines.to_a
          str << "in macro '#{@filename.macro.name}' #{@filename.macro.filename}:#{@filename.macro.line_number}, line #{@line}:\n\n"
          str << lines.to_s_with_line_numbers
        else
          lines = File.readlines @filename
          str << "in #{@filename}:#{@line}: #{msg}"
        end
      else
        lines = source ? source.lines.to_a : nil
        if @line
          str << "in line #{@line}: "
        end
        str << msg
      end

      if lines && @line
        line = lines[@line - 1]
        if line
          str << "\n\n"
          str << line.chomp
          str << "\n"
          str << (' ' * (@column - 1))
          str << '^'
          if @length && @length > 0
            str << ('~' * (@length - 1))
          end
        end
      end
      str << "\n"
      if inner && inner.has_location?
        str << "\n"
        inner.append_to_s(str, source)
      end
    end

    def file_exists?(filename)
      filename.is_a?(VirtualFile) || File.file?(filename)
    end

    def has_location?
      if inner && inner.has_location?
        true
      else
        @filename || @line
      end
    end

    def deepest_error_message
      if inner
        inner.deepest_error_message
      else
        @message
      end
    end
  end

  class NilMethodException < Exception
    def initialize(nil_trace)
      @nil_trace = nil_trace
    end

    def has_location?
      true
    end

    def append_to_s(str, source)
      return unless @nil_trace.length > 0

      str << ("=" * 80)
      str << "\n\nNil trace:"
      @nil_trace.each do |node|
        if node.filename.is_a?(VirtualFile)
          filename = "macro #{node.filename.macro.name} (in #{node.filename.macro.filename}:#{node.filename.macro.line_number})"
          lines = node.filename.source.lines.to_a
        elsif node.filename
          filename = node.filename
          lines = File.readlines filename
        else
          next
        end

        line_number = node.line_number
        column_number = node.column_number

        str << "\n\n"
        str << "  "
        str << filename
        str << ":"
        str << line_number.to_s
        str << "\n\n"

        line = lines[line_number - 1]

        name_column, name_length = Exception.name_column_and_length(node)

        str << "    "
        str << line.chomp
        str << "\n"
        str << "    "
        str << (' ' * (name_column - 1))
        str << '^'
        str << ('~' * (name_length - 1)) if name_length
      end
    end
  end

  class FrozenTypeException < TypeException
  end
end
