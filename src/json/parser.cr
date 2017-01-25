require "./lexer"

class JSON::Parser
  property max_nesting = 512

  def initialize(string_or_io : String | IO)
    @lexer = JSON::Lexer.new(string_or_io)
    @nest = 0
    next_token
  end

  def parse : Type
    json = parse_value
    check :EOF
    json
  end

  private def parse_value
    case token.type
    when :INT
      value_and_next_token token.int_value
    when :FLOAT
      value_and_next_token token.float_value
    when :STRING
      value_and_next_token token.string_value
    when :null
      value_and_next_token nil
    when :true
      value_and_next_token true
    when :false
      value_and_next_token false
    when :"["
      parse_array
    when :"{"
      parse_object
    else
      unexpected_token
    end
  end

  private def parse_array
    next_token

    ary = [] of Type

    nest do
      if token.type != :"]"
        while true
          ary << parse_value

          case token.type
          when :","
            next_token
            unexpected_token if token.type == :"]"
          when :"]"
            break
          else
            unexpected_token
          end
        end
      end
    end

    next_token

    ary
  end

  private def parse_object
    next_token_expect_object_key

    object = {} of String => Type

    nest do
      if token.type != :"}"
        while true
          check :STRING
          key = token.string_value

          next_token

          check :":"
          next_token

          value = parse_value

          object[key] = value

          case token.type
          when :","
            next_token_expect_object_key
            unexpected_token if token.type == :"}"
          when :"}"
            break
          else
            unexpected_token
          end
        end
      end
    end

    next_token

    object
  end

  private delegate token, to: @lexer
  private delegate next_token, to: @lexer
  private delegate next_token_expect_object_key, to: @lexer

  private def value_and_next_token(value)
    next_token
    value
  end

  private def check(token_type)
    unexpected_token unless token.type == token_type
  end

  private def unexpected_token
    parse_exception "unexpected token '#{token}'"
  end

  private def parse_exception(msg)
    raise ParseException.new(msg, token.line_number, token.column_number)
  end

  private def nest
    @nest += 1
    if @nest > @max_nesting
      parse_exception "Nesting of #{@nest} is too deep"
    end

    yield
    @nest -= 1
  end
end
