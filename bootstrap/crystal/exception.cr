module Crystal
  class Exception < ::Exception
  end

  class SyntaxException < Exception
    def initialize(message, @line_number, @column_number, @filename)
      super(message)
    end

    def to_s
      str = StringBuilder.new
      if @filename
        str << "Syntax error in #{@filename}:#{@line_number}: #{@message}"
      else
        str << "Syntax error in line #{@line_number}: #{@message}"
      end

      if @filename && File.exists?(@filename)
        source = File.read(@filename)
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

      str.to_s
    end
  end

  class TypeException < Exception
    getter :node
    getter :inner

    def self.for_node(node, message, inner = nil)
      location = node.location
      if location
        new message, location.line_number, location.column_number, location.filename, 0, inner
      else
        new message, 0, 0, "", 0, inner
      end
    end

    def initialize(message, @line, @column, @filename, @length = nil, @inner = nil)
      super(message)
    end
  end
end
