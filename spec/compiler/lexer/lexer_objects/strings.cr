module LexerObjects
  class Strings
    @lexer : Lexer
    @token : Token

    private def t(kind : Token::Kind)
      kind
    end

    def initialize(@lexer)
      @token = Token.new
    end

    def string_should_be_delimited_by(expected_start, expected_end)
      string_should_start_correctly
      token.delimiter_state.nest.should eq(expected_start)
      token.delimiter_state.end.should eq(expected_end)
      token.delimiter_state.open_count.should eq(0)
    end

    def string_should_start_correctly
      @token = lexer.next_token
      token.type.should eq(t :DELIMITER_START)
    end

    def next_token_should_be(expected_type : Token::Kind, expected_value = nil)
      @token = lexer.next_token
      token.type.should eq(expected_type)
      if expected_value
        token.value.should eq(expected_value)
      end
    end

    def next_unicode_tokens_should_be(expected_unicode_codes : Array)
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :STRING)
      token.value.as(String).chars.map(&.ord).should eq(expected_unicode_codes)
    end

    def next_unicode_tokens_should_be(expected_unicode_codes)
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :STRING)
      token.value.as(String).char_at(0).ord.should eq(expected_unicode_codes)
    end

    def next_string_token_should_be(expected_string)
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :STRING)
      token.value.should eq(expected_string)
    end

    def next_string_token_should_be_opening
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :STRING)
      token.value.should eq(token.delimiter_state.nest.to_s)
      token.delimiter_state.open_count.should eq(1)
    end

    def next_string_token_should_be_closing
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :STRING)
      token.value.should eq(token.delimiter_state.end.to_s)
      token.delimiter_state.open_count.should eq(0)
    end

    def string_should_have_an_interpolation_of(interpolated_variable_name)
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :INTERPOLATION_START)

      @token = lexer.next_token
      token.type.should eq(t :IDENT)
      token.value.should eq(interpolated_variable_name)

      @token = lexer.next_token
      token.type.should eq(t :OP_RCURLY)
    end

    def token_should_be_at(line = nil, column = nil)
      token.line_number.should eq(line) if line
      token.column_number.should eq(column) if column
    end

    def next_token_should_be_at(line = nil, column = nil)
      @token = lexer.next_token
      token_should_be_at(line: line, column: column)
    end

    def string_should_end_correctly(eof = true)
      @token = lexer.next_string_token(token.delimiter_state)
      token.type.should eq(t :DELIMITER_END)
      if eof
        should_have_reached_eof
      end
    end

    def should_have_reached_eof
      @token = lexer.next_token
      token.type.should eq(t :EOF)
    end

    private getter :lexer, :token
  end
end
