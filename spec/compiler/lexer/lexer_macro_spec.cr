#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Lexer macro" do
  it "lexes simple macro" do
    lexer = Lexer.new(%(hello end))

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("h")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("ello ")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with expression" do
    lexer = Lexer.new(%(hello {{world}} end))

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("h")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("ello ")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_EXPRESSION)
    token.value.should eq("world")
    token.macro_whitespace.should eq(false)

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(" ")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_END)
  end

  %w(begin do if unless class struct module def while until case macro).each do |keyword|
    it "lexes macro with nested #{keyword}" do
      lexer = Lexer.new(%(hello #{keyword} {{world}} end end))

      token = lexer.next_macro_token
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("h")

      token = lexer.next_macro_token
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("ello #{keyword} ")
      token.macro_nest.should eq(1)

      token = lexer.next_macro_token
      token.type.should eq(:MACRO_EXPRESSION)
      token.value.should eq("world")

      token = lexer.next_macro_token
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq(" ")

      token = lexer.next_macro_token
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("end ")

      token = lexer.next_macro_token
      token.type.should eq(:MACRO_END)
    end
  end

  it "lexes macro without nested if" do
    lexer = Lexer.new(%(helloif {{world}} end))

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("h")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("elloif ")
    token.macro_nest.should eq(0)

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_EXPRESSION)
    token.value.should eq("world")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(" ")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_END)
  end

  it "reaches end" do
    lexer = Lexer.new(%(fail))

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("fail")

    token = lexer.next_macro_token
    token.type.should eq(:EOF)
  end

  it "keeps correct column and line numbers" do
    lexer = Lexer.new("\nfoo\nbarf{{var}}end")

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("\nfoo\nbarf")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_EXPRESSION)
    token.value.should eq("var")
    token.line_number.should eq(3)
    token.column_number.should eq(7)

    token = lexer.next_macro_token
    token.type.should eq(:MACRO_END)
  end
end
