module ECR
  extend self

  DefaultBufferName = "__str__"

  def process_file(filename, buffer_name = DefaultBufferName)
    process_string File.read(filename), filename, buffer_name
  end

  def process_string(string, filename, buffer_name = DefaultBufferName)
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
          append_loc(str, filename, token)
          str << token.value
          str << "\n"
        when :CONTROL
          append_loc(str, filename, token)
          str << token.value
          str << "\n"
        when :EOF
          break
        end
      end
      str << "end"
    end
  end

  def append_loc(str, filename, token)
    str << %(#<loc:")
    str << filename
    str << %(",)
    str << token.line_number
    str << %(,)
    str << token.column_number
    str << %(>)
  end
end

require "./lexer"


