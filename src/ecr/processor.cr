require "./ecr/lexer"

module ECR
  extend self

  DefaultBufferName = "__str__"

  class Line
    
    getter :tokens
    
    def initialize()
      @tokens = Array(Lexer::Token).new
      @indent = true
      @newline = true
    end
    
    def suppress_leading?
      suppress = false
      tokens.each do |token|
        suppress = suppress || token.suppress_leading?
        suppress = suppress || suppress && token.is_whitespace?
      end
      suppress
    end
    
    def suppress_leading!
      while tokens.first.is_whitespace?
        tokens.shift
      end
    end
    
    def suppress_trailing?
      suppress = false
      tokens.each do |token|
        suppress = suppress || token.suppress_trailing?
        suppress = suppress || suppress && token.is_whitespace?
      end
      suppress
    end
    
    def suppress_trailing!
      while tokens.last.is_whitespace?
        tokens.pop
      end
    end

    def suppress!
      suppress_leading! if suppress_leading?
      suppress_trailing! if suppress_trailing?
    end
    
    def append_value(str, buffer_name, filename)
      suppress!
      @tokens.each {|t| t.append_value(str, buffer_name, filename)}
    end
  end
  
  # :nodoc:
  def process_file(filename, buffer_name = DefaultBufferName)
    process_string File.read(filename), filename, buffer_name
  end

  # :nodoc:
  def process_string(string, filename, buffer_name = DefaultBufferName)
    lexer = Lexer.new string
    lines = Array(Line).new
    line = Line.new
    while true
      token = lexer.next_token
      if token.type == :EOF
        lines << line
        break
      end
      if token.line_number > lines.size + 1
        lines << line
        line = Line.new
      end
      line.tokens << token.dup
    end
    String.build do |str|
      lines.each {|l| l.append_value(str, buffer_name, filename) }
    end
  end

end
