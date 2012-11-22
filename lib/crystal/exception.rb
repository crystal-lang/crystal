module Crystal
  class Exception < StandardError
    def message(source = nil)
      to_s(source)
    end
  end

  class SyntaxException < Exception
    def initialize(message, line_number, column_number)
      @message = message
      @line_number = line_number
      @column_number = column_number
    end

    def to_s(source = nil)
      str = "Syntax error in line #{@line_number}: #{@message}"
      if source
        lines = source.lines.to_a
        str << "\n\n"
        str << lines[@line_number - 1].chomp
        str << "\n"
        str << (' ' * (@column_number - 1))
        str << '^'
        str << "\n"
      end
      str
    end
  end

  class TypeException < Exception
    attr_accessor :node
    attr_accessor :inner

    def self.for_node(node, message, inner = nil)
      if node.respond_to?(:name)
        length = node.respond_to?(:name_length) ? node.name_length : node.name.length
        if node.respond_to?(:name_column_number)
          new message, node.line_number, node.name_column_number, length, inner
        else
          new message, node.line_number, node.column_number, length, inner
        end
      else
        new message, node.line_number, node.column_number, nil, inner
      end
    end

    def initialize(message, line, column, length = nil, inner = nil)
      @message = message
      @line = line
      @column = column
      @length = length
      @inner = inner
    end

    def to_s(source = nil)
      lines = source ? source.lines.to_a : nil
      str = 'Error '
      append_to_s(str, lines)
      str
    end

    def append_to_s(str, lines)
      str << "in line #{@line}: #{@message}"
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
      if inner
        str << "\n"
        inner.append_to_s(str, lines)
      end
    end
  end
end
