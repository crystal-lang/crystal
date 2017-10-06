require "./lexer"

module ECR
  extend self

  DefaultBufferName = "__str__"

  # :nodoc:
  def process_file(filename, buffer_name = DefaultBufferName)
    process_string File.read(filename), filename, buffer_name
  end

  # :nodoc:
  def process_string(string, filename, buffer_name = DefaultBufferName)
    lexer = Lexer.new string
    token = lexer.next_token

    String.build do |str|
      while true
        case token.type
        when :STRING
          string = token.value
          token = lexer.next_token

          string = supress_leading_indentation(token, string)

          str << buffer_name
          str << " << "
          string.inspect(str)
          str << "\n"
        when :OUTPUT
          string = token.value
          line_number = token.line_number
          column_number = token.column_number
          supress_trailing = token.supress_trailing?
          token = lexer.next_token

          supress_trailing_whitespace(token, supress_trailing)

          str << "("
          append_loc(str, filename, line_number, column_number)
          str << string
          str << ").to_s "
          str << buffer_name
          str << "\n"
        when :CONTROL
          string = token.value
          line_number = token.line_number
          column_number = token.column_number
          supress_trailing = token.supress_trailing?
          token = lexer.next_token

          supress_trailing_whitespace(token, supress_trailing)

          append_loc(str, filename, line_number, column_number)
          str << " " unless string.starts_with?(' ')
          str << string
          str << "\n"
        when :EOF
          break
        end
      end
    end
  end

  private def supress_leading_indentation(token, string)
    # To supress leading indentation we find the last index of a newline and
    # then check if all chars after that are whitespace.
    # We use a Char::Reader for this for maximum efficiency.
    if (token.type == :OUTPUT || token.type == :CONTROL) && token.supress_leading?
      char_index = string.rindex('\n')
      char_index = char_index ? char_index + 1 : 0
      byte_index = string.char_index_to_byte_index(char_index).not_nil!
      reader = Char::Reader.new(string)
      reader.pos = byte_index
      while reader.current_char.ascii_whitespace? && reader.has_next?
        reader.next_char
      end
      if reader.pos == string.bytesize
        string = string.byte_slice(0, byte_index)
      end
    end
    string
  end

  private def supress_trailing_whitespace(token, supress_trailing)
    if supress_trailing && token.type == :STRING
      newline_index = token.value.index('\n')
      token.value = token.value[newline_index + 1..-1] if newline_index
    end
  end

  private def append_loc(str, filename, line_number, column_number)
    str << %(#<loc:")
    str << filename
    str << %(",)
    str << line_number
    str << %(,)
    str << column_number
    str << %(>)
  end
end
