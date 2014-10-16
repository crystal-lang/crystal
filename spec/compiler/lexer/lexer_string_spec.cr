#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Lexer string" do
  it "lexes simple string" do
    lexer = Lexer.new(%("hello"))

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token.delimiter_state.end.should eq('"')
    token.delimiter_state.nest.should eq('"')
    token.delimiter_state.open_count.should eq(0)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes string with newline" do
    lexer = Lexer.new("\"hello\\nworld\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with slash" do
    lexer = Lexer.new("\"hello\\\\world\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("\\")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with slash quote" do
    lexer = Lexer.new("\"\\\"\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("\"")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with slash t" do
    lexer = Lexer.new("\"\\t\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("\t")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with interpolation" do
    lexer = Lexer.new("\"hello \#{world}\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:INTERPOLATION_START)

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    token = lexer.next_token
    token.type.should eq(:"}")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with numeral" do
    lexer = Lexer.new("\"hello#world\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with literal newline" do
    lexer = Lexer.new("\"hello\nworld\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)

    token = lexer.next_token
    token.line_number.should eq(2)
    token.column_number.should eq(7)
  end

  it "lexes string with only newline" do
    lexer = Lexer.new("\"\n\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes double numeral" do
    lexer = Lexer.new("\"##\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes string with interpolation with double numeral" do
    lexer = Lexer.new("\"hello \#\#{world}\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:INTERPOLATION_START)

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    token = lexer.next_token
    token.type.should eq(:"}")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes slash with no-escape char" do
    lexer = Lexer.new("\"\\h\"")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("h")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)
  end

  it "lexes simple string with %(" do
    lexer = Lexer.new("%(hello)")

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token.delimiter_state.end.should eq(')')
    token.delimiter_state.nest.should eq('(')

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  [['(', ')'], ['[', ']'], ['{', '}'], ['<', '>']].each do |pair|
    it "lexes simple string with nested %#{pair[0]}" do
      lexer = Lexer.new("%#{pair[0]}hello #{pair[0]}world#{pair[1]}#{pair[1]}")

      token = lexer.next_token
      token.type.should eq(:DELIMITER_START)
      token.delimiter_state.nest.should eq(pair[0])
      token.delimiter_state.end.should eq(pair[1])
      token.delimiter_state.open_count.should eq(0)

      delimiter_state = token.delimiter_state

      token = lexer.next_string_token(delimiter_state)
      token.type.should eq(:STRING)
      token.value.should eq("hello ")

      token = lexer.next_string_token(delimiter_state)
      token.type.should eq(:STRING)
      token.value.should eq(pair[0].to_s)
      token.delimiter_state.open_count.should eq(1)

      delimiter_state = token.delimiter_state

      token = lexer.next_string_token(delimiter_state)
      token.type.should eq(:STRING)
      token.value.should eq("world")

      token = lexer.next_string_token(delimiter_state)
      token.type.should eq(:STRING)
      token.value.should eq(pair[1].to_s)
      token.delimiter_state.open_count.should eq(0)

      delimiter_state = token.delimiter_state

      token = lexer.next_string_token(delimiter_state)
      token.type.should eq(:DELIMITER_END)

      token = lexer.next_token
      token.type.should eq(:EOF)
    end
  end

  it "lexes heredoc" do
    string = "Hello, mom! I am HERE.\nHER dress is beatiful.\nHE is OK.\n  HERE"
    lexer = Lexer.new("<<-HERE\n#{string}\nHERE")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq(string)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes string with unicode codepoint" do
    lexer = Lexer.new "\"\\uFEDA\""
    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(:STRING)
    (token.value as String).char_at(0).ord.should eq(0xFEDA)
  end

  it "lexes string with unicode codepoint in curly" do
    lexer = Lexer.new "\"\\u{A5}\""
    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(:STRING)
    (token.value as String).char_at(0).ord.should eq(0xA5)
  end

  it "lexes string with unicode codepoint in curly multiple times" do
    lexer = Lexer.new "\"\\u{A5 A6 10FFFF}\""
    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(:STRING)
    string = token.value as String
    string.chars.map(&.ord).should eq([0xA5, 0xA6, 0x10FFFF])
  end

  assert_syntax_error "\"\\uFEDZ\"", "expected hexadecimal character in unicode escape"
  assert_syntax_error "\"\\u{}\"", "expected hexadecimal character in unicode escape"
  assert_syntax_error "\"\\u{110000}\"", "invalid unicode codepoint (too large)"

  it "lexes backtick string" do
    lexer = Lexer.new(%(`hello`))

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token.delimiter_state.end.should eq('`')
    token.delimiter_state.nest.should eq('`')
    token.delimiter_state.open_count.should eq(0)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes regex string" do
    lexer = Lexer.new(%(/hello/))

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token.delimiter_state.end.should eq('/')
    token.delimiter_state.nest.should eq('/')
    token.delimiter_state.open_count.should eq(0)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes string with backslash" do
    lexer = Lexer.new(%("hello \\\n    world"1))

    token = lexer.next_token
    token.type.should eq(:DELIMITER_START)
    token.delimiter_state.end.should eq('"')
    token.delimiter_state.nest.should eq('"')
    token.delimiter_state.open_count.should eq(0)

    delimiter_state = token.delimiter_state

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token(delimiter_state)
    token.type.should eq(:DELIMITER_END)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(2)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end
end
