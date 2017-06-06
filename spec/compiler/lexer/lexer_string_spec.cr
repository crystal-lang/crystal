require "../../support/syntax"
require "./lexer_objects/strings"

describe "Lexer string" do
  it "lexes simple string" do
    lexer = Lexer.new(%("hello"))
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('"', '"')
    tester.next_string_token_should_be("hello")
    tester.string_should_end_correctly
  end

  it "lexes string with newline" do
    lexer = Lexer.new("\"hello\\nworld\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("hello")
    tester.next_string_token_should_be("\n")
    tester.next_string_token_should_be("world")
    tester.string_should_end_correctly
  end

  it "lexes string with slash" do
    lexer = Lexer.new("\"hello\\\\world\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("hello")
    tester.next_string_token_should_be("\\")
    tester.next_string_token_should_be("world")
    tester.string_should_end_correctly
  end

  it "lexes string with slash quote" do
    lexer = Lexer.new("\"\\\"\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("\"")
    tester.string_should_end_correctly
  end

  it "lexes string with slash t" do
    lexer = Lexer.new("\"\\t\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("\t")
    tester.string_should_end_correctly
  end

  it "lexes string with interpolation" do
    lexer = Lexer.new("\"hello \#{world}\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("hello ")
    tester.string_should_have_an_interpolation_of("world")
    tester.string_should_end_correctly
  end

  it "lexes string with numeral" do
    lexer = Lexer.new("\"hello#world\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("hello")
    tester.next_string_token_should_be("#")
    tester.next_string_token_should_be("world")
    tester.string_should_end_correctly
  end

  it "lexes string with literal newline" do
    lexer = Lexer.new("\"hello\nworld\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("hello")
    tester.next_string_token_should_be("\n")
    tester.next_string_token_should_be("world")
    tester.string_should_end_correctly
    tester.next_token_should_be_at(line: 2, column: 7)
  end

  it "lexes string with only newline" do
    lexer = Lexer.new("\"\n\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("\n")
    tester.string_should_end_correctly
  end

  it "lexes double numeral" do
    lexer = Lexer.new("\"##\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("#")
    tester.next_string_token_should_be("#")
    tester.string_should_end_correctly
  end

  it "lexes string with interpolation with double numeral" do
    lexer = Lexer.new("\"hello \#\#{world}\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("hello ")
    tester.next_string_token_should_be("#")
    tester.string_should_have_an_interpolation_of("world")
    tester.string_should_end_correctly
  end

  it "lexes slash with no-escape char" do
    lexer = Lexer.new("\"\\h\"")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("h")
    tester.string_should_end_correctly
  end

  it "lexes simple string with %(" do
    lexer = Lexer.new("%(hello)")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('(', ')')
    tester.next_string_token_should_be("hello")
    tester.string_should_end_correctly
  end

  it "lexes simple string with %|" do
    lexer = Lexer.new("%|hello|")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('|', '|')
    tester.next_string_token_should_be("hello")
    tester.string_should_end_correctly
  end

  [['(', ')'], ['[', ']'], ['{', '}'], ['<', '>']].each do |(left, right)|
    it "lexes simple string with nested %#{left}" do
      lexer = Lexer.new("%#{left}hello #{left}world#{right}#{right}")
      tester = LexerObjects::Strings.new(lexer)

      tester.string_should_be_delimited_by(left, right)
      tester.next_string_token_should_be("hello ")
      tester.next_string_token_should_be_opening
      tester.next_string_token_should_be("world")
      tester.next_string_token_should_be_closing
      tester.string_should_end_correctly
    end
  end

  it "lexes heredoc" do
    string = "Hello, mom! I am HERE.\nHER dress is beautiful.\nHE is OK.\n  HERESY"
    lexer = Lexer.new("<<-HERE\n#{string}\nHERE")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("Hello, mom! I am HERE.")
    tester.next_string_token_should_be("\nHER dress is beautiful.")
    tester.next_string_token_should_be("\nHE is OK.")
    tester.next_string_token_should_be("\n  HERESY")
    tester.string_should_end_correctly
  end

  it "lexes heredoc with empty line" do
    lexer = Lexer.new("<<-XML\nfoo\n\nXML")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("foo")
    tester.next_string_token_should_be("\n")
    tester.string_should_end_correctly
  end

  it "lexes heredoc with \\r\\n" do
    lexer = Lexer.new("<<-XML\r\nfoo\r\n\nXML")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("foo")
    tester.next_string_token_should_be("\r\n")
    tester.string_should_end_correctly
  end

  it "lexes heredoc with spaces before close tag" do
    lexer = Lexer.new("<<-XML\nfoo\n   XML")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("foo")
    tester.string_should_end_correctly
  end

  it "assigns correct location after heredoc (#346)" do
    string = "Hello, mom! I am HERE.\nHER dress is beautiful.\nHE is OK."
    lexer = Lexer.new("<<-HERE\n#{string}\nHERE\n1")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("Hello, mom! I am HERE.")
    tester.token_should_be_at(line: 2)
    tester.next_string_token_should_be("\nHER dress is beautiful.")
    tester.token_should_be_at(line: 3)
    tester.next_string_token_should_be("\nHE is OK.")
    tester.token_should_be_at(line: 4)
    tester.string_should_end_correctly(false)
    tester.next_token_should_be(:NEWLINE)
    tester.token_should_be_at(line: 5, column: 5)
    tester.next_token_should_be(:NUMBER)
    tester.token_should_be_at(line: 6, column: 1)
  end

  it "lexes interpolations in heredocs" do
    lexer = Lexer.new("<<-HERE\n\abc\#{foo}\nHERE")
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_string_token_should_be("abc")
    tester.string_should_have_an_interpolation_of("foo")
    tester.string_should_end_correctly
  end

  it "raises on unterminated heredoc" do
    lexer = Lexer.new("<<-HERE\nHello")
    token = lexer.next_token
    state = token.delimiter_state

    expect_raises Crystal::SyntaxException, /unterminated heredoc/ do
      loop do
        token = lexer.next_string_token state
        break if token.type == :DELIMITER_END
      end
    end
  end

  it "raises on invalid heredoc identifier (<<-HERE A)" do
    lexer = Lexer.new("<<-HERE A\ntest\nHERE\n")

    expect_raises Crystal::SyntaxException, /invalid character '.+' for heredoc identifier/ do
      lexer.next_token
    end
  end

  it "raises on invalid heredoc identifier (<<-HERE\\n)" do
    lexer = Lexer.new("<<-HERE\\ntest\nHERE\n")

    expect_raises Crystal::SyntaxException, /invalid character '.+' for heredoc identifier/ do
      lexer.next_token
    end
  end

  it "raises when identifier doesn't start with a leter" do
    lexer = Lexer.new("<<-123\\ntest\n123\n")

    expect_raises Crystal::SyntaxException, /heredoc identifier starts with invalid character/ do
      lexer.next_token
    end
  end

  it "raises when identifier contains a character not for identifier" do
    lexer = Lexer.new("<<-aaa.bbb?\\ntest\naaa.bbb?\n")

    expect_raises Crystal::SyntaxException, /invalid character '.+' for heredoc identifier/ do
      lexer.next_token
    end
  end

  it "raises when identifier contains spaces" do
    lexer = Lexer.new("<<-aaa  bbb\\ntest\naaabbb\n")

    expect_raises Crystal::SyntaxException, /invalid character '.+' for heredoc identifier/ do
      lexer.next_token
    end
  end

  it "raises on unexpected EOF while lexing heredoc" do
    lexer = Lexer.new("<<-aaa")

    expect_raises Crystal::SyntaxException, /unexpected EOF on heredoc identifier/ do
      lexer.next_token
    end
  end

  it "lexes string with unicode codepoint" do
    lexer = Lexer.new "\"\\uFEDA\""
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_unicode_tokens_should_be(0xFEDA)
  end

  it "lexes string with unicode codepoint in curly" do
    lexer = Lexer.new "\"\\u{A5}\""
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_unicode_tokens_should_be(0xA5)
  end

  it "lexes string with unicode codepoint in curly multiple times" do
    lexer = Lexer.new "\"\\u{A5 A6 10FFFF}\""
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_start_correctly
    tester.next_unicode_tokens_should_be([0xA5, 0xA6, 0x10FFFF])
  end

  assert_syntax_error "\"\\uFEDZ\"", "expected hexadecimal character in unicode escape"
  assert_syntax_error "\"\\u{}\"", "expected hexadecimal character in unicode escape"
  assert_syntax_error "\"\\u{110000}\"", "invalid unicode codepoint (too large)"

  it "lexes backtick string" do
    lexer = Lexer.new(%(`hello`))
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('`', '`')
    tester.next_string_token_should_be("hello")
    tester.string_should_end_correctly
  end

  it "lexes regex string" do
    lexer = Lexer.new(%(/hello/))
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('/', '/')
    tester.next_string_token_should_be("hello")
    tester.string_should_end_correctly
  end

  it "lexes regex string with special chars with /.../" do
    lexer = Lexer.new(%(/\\w/))
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('/', '/')
    tester.next_string_token_should_be("\\w")
    tester.string_should_end_correctly
  end

  it "lexes regex string with special chars with %r(...)" do
    lexer = Lexer.new(%(%r(\\w)))

    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('(', ')')
    tester.next_string_token_should_be("\\w")
    tester.string_should_end_correctly
  end

  it "lexes string with backslash" do
    lexer = Lexer.new(%("hello \\\n    world"1))
    tester = LexerObjects::Strings.new(lexer)

    tester.string_should_be_delimited_by('"', '"')
    tester.next_string_token_should_be("hello ")
    tester.next_string_token_should_be("world")
    tester.string_should_end_correctly(eof: false)
    tester.next_token_should_be(:NUMBER)
    tester.token_should_be_at(line: 2)
    tester.should_have_reached_eof
  end
end
