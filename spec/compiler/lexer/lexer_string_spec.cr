#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Lexer string" do
  it "lexes simple string" do
    lexer = Lexer.new(%("hello"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)
    token.string_end.should eq('"')
    token.string_nest.should eq('"')
    token.string_open_count.should eq(0)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes string with newline" do
    lexer = Lexer.new("\"hello\\nworld\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with slash" do
    lexer = Lexer.new("\"hello\\\\world\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("\\")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with slash quote" do
    lexer = Lexer.new("\"\\\"\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("\"")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with slash t" do
    lexer = Lexer.new("\"\\t\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("\t")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with interpolation" do
    lexer = Lexer.new("\"hello \#{world}\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:INTERPOLATION_START)

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    token = lexer.next_token
    token.type.should eq(:"}")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with numeral" do
    lexer = Lexer.new("\"hello#world\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with literal newline" do
    lexer = Lexer.new("\"hello\nworld\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)

    token = lexer.next_token
    token.line_number.should eq(2)
    token.column_number.should eq(7)
  end

  it "lexes string with only newline" do
    lexer = Lexer.new("\"\n\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes double numeral" do
    lexer = Lexer.new("\"##\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes string with interpolation with double numeral" do
    lexer = Lexer.new("\"hello \#\#{world}\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:INTERPOLATION_START)

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    token = lexer.next_token
    token.type.should eq(:"}")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes slash with no-escape char" do
    lexer = Lexer.new("\"\\h\"")

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING)
    token.value.should eq("h")

    token = lexer.next_string_token('"', '"', 0)
    token.type.should eq(:STRING_END)
  end

  it "lexes simple string with %(" do
    lexer = Lexer.new("%(hello)")

    token = lexer.next_token
    token.type.should eq(:STRING_START)
    token.string_end.should eq(')')
    token.string_nest.should eq('(')

    token = lexer.next_string_token('(', ')', 0)
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token('(', ')', 0)
    token.type.should eq(:STRING_END)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  [['(', ')'], ['[', ']'], ['{', '}'], ['<', '>']].each do |pair|
    it "lexes simple string with nested %#{pair[0]}" do
      lexer = Lexer.new("%#{pair[0]}hello #{pair[0]}world#{pair[1]}#{pair[1]}")

      token = lexer.next_token
      token.type.should eq(:STRING_START)
      token.string_nest.should eq(pair[0])
      token.string_end.should eq(pair[1])
      token.string_open_count.should eq(0)

      token = lexer.next_string_token(pair[0], pair[1], 0)
      token.type.should eq(:STRING)
      token.value.should eq("hello ")

      token = lexer.next_string_token(pair[0], pair[1], 0)
      token.type.should eq(:STRING)
      token.value.should eq(pair[0].to_s)
      token.string_open_count.should eq(1)

      token = lexer.next_string_token(pair[0], pair[1], 1)
      token.type.should eq(:STRING)
      token.value.should eq("world")

      token = lexer.next_string_token(pair[0], pair[1], 1)
      token.type.should eq(:STRING)
      token.value.should eq(pair[1].to_s)
      token.string_open_count.should eq(0)

      token = lexer.next_string_token(pair[0], pair[1], 0)
      token.type.should eq(:STRING_END)

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
end
