module ECR
  extend self

  def process_ecr(string, buffer_name = "__str__")
    lexer = Lexer.new string

    String.build do |str|
      str << "String.build do |"
      str << buffer_name
      str << "|\n"
      while true
        token = lexer.next_token
        case token.type
        when :STRING
          str << buffer_name
          str << " << \""
          str << token.value.dump
          str << "\"\n"
        when :OUTPUT
          str << buffer_name
          str << " << "
          str << token.value
          str << "\n"
        when :CONTROL
          str << token.value
          str << "\n"
        when :EOF
          break
        end
      end
      str << "end"
    end
  end
end

require "./*"


