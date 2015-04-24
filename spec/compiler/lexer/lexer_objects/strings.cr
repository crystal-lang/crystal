module LexerObjects
  class Strings
    def initialize(@lexer)
      @token = Token.new
    end

    def string_should_be_delimited_by(expected_start, expected_end)
      string_should_start_correctly
      expect(token.delimiter_state.nest).to eq(expected_start)
      expect(token.delimiter_state.end).to eq(expected_end)
      expect(token.delimiter_state.open_count).to eq(0)
    end

    def string_should_start_correctly
      @token = lexer.next_token
      expect(token.type).to eq(:DELIMITER_START)
    end

    def next_token_should_be(expected_type, expected_value = nil)
      @token = lexer.next_token
      expect(token.type).to eq(expected_type)
      if expected_value
        expect(token.value).to eq(expected_value)
      end
    end

    def next_unicode_tokens_should_be(expected_unicode_codes : Array)
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:STRING)
      expect((token.value as String).chars.map(&.ord)).to eq(expected_unicode_codes)
    end

    def next_unicode_tokens_should_be(expected_unicode_codes)
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:STRING)
      expect((token.value as String).char_at(0).ord).to eq(expected_unicode_codes)
    end

    def next_string_token_should_be(expected_string)
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:STRING)
      expect(token.value).to eq(expected_string)
    end

    def next_string_token_should_be_opening
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:STRING)
      expect(token.value).to eq(token.delimiter_state.nest.to_s)
      expect(token.delimiter_state.open_count).to eq(1)
    end

    def next_string_token_should_be_closing
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:STRING)
      expect(token.value).to eq(token.delimiter_state.end.to_s)
      expect(token.delimiter_state.open_count).to eq(0)
    end

    def string_should_have_an_interpolation_of(interpolated_variable_name)
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:INTERPOLATION_START)

      @token = lexer.next_token
      expect(token.type).to eq(:IDENT)
      expect(token.value).to eq(interpolated_variable_name)

      @token = lexer.next_token
      expect(token.type).to eq(:"}")
    end

    def token_should_be_at(line = nil, column = nil)
      expect(token.line_number).to eq(line) if line
      expect(token.column_number).to eq(column) if column
    end

    def next_token_should_be_at(line = nil, column = nil)
      @token = lexer.next_token
      token_should_be_at(line: line, column: column)
    end

    def string_should_end_correctly(eof = true)
      @token = lexer.next_string_token(token.delimiter_state)
      expect(token.type).to eq(:DELIMITER_END)
      if eof
        should_have_reached_eof
      end
    end

    def should_have_reached_eof
      @token = lexer.next_token
      expect(token.type).to eq(:EOF)
    end

    private getter :lexer, :token
  end
end
