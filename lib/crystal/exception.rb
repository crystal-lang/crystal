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
    end
  end

  class TypeException < Exception
    attr_accessor :node
    attr_accessor :inner

    def initialize(message, node = nil, inner = nil)
      @message = message
      @node = node
      @inner = inner
    end

    def to_s(source = nil)
      lines = source ? source.lines.to_a : nil
      str = 'Error '
      append_to_s(str, lines)
      str
    end

    def append_to_s(str, lines)
      if node
        str << "in line #{node.line_number}: #{@message}"
      else
        str << "#{@message}"
      end
      if lines && node
        str << "\n\n"
        str << lines[node.line_number - 1].chomp
        if node.respond_to?(:name)
          str << "\n"
          if node.respond_to?(:name_column_number)
            str << (' ' * (node.name_column_number - 1))
          else
            str << (' ' * (node.column_number - 1))
          end
          str << '^'
          str << ('~' * (node.name_length - 1))
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
