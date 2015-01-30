require "../../spec_helper"
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

  [['(', ')'], ['[', ']'], ['{', '}'], ['<', '>']].each do |pair|
    it "lexes simple string with nested %#{pair[0]}" do
      lexer = Lexer.new("%#{pair[0]}hello #{pair[0]}world#{pair[1]}#{pair[1]}")
      tester = LexerObjects::Strings.new(lexer)

      tester.string_should_be_delimited_by(pair[0], pair[1])
      tester.next_string_token_should_be("hello ")
      tester.next_string_token_should_be_opening
      tester.next_string_token_should_be("world")
      tester.next_string_token_should_be_closing
      tester.string_should_end_correctly
    end
  end

  it "lexes heredoc" do
    string = "Hello, mom! I am HERE.\nHER dress is beatiful.\nHE is OK.\n  HERE\nHERESY"
    lexer = Lexer.new("<<-HERE\n#{string}\nHERE")
    tester = LexerObjects::Strings.new(lexer)

    tester.next_token_should_be(:STRING, string)
    tester.should_have_reached_eof
  end

  it "assigns correct location after heredoc (#346)" do
    string = "Hello, mom! I am HERE.\nHER dress is beatiful.\nHE is OK.\n  HERE"
    lexer = Lexer.new("<<-HERE\n#{string}\nHERE\n1")
    tester = LexerObjects::Strings.new(lexer)

    tester.next_token_should_be(:STRING, string)
    tester.token_should_be_at(line: 1, column: 1)
    tester.next_token_should_be(:NEWLINE)
    tester.token_should_be_at(line: 6, column: 5)
    tester.next_token_should_be(:NUMBER)
    tester.token_should_be_at(line: 7, column: 1)
    tester.should_have_reached_eof
  end

  it "raises on unterminated heredoc" do
    lexer = Lexer.new("<<-HERE\nHello")

    expect_raises Crystal::SyntaxException, /unterminated heredoc/ do
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
