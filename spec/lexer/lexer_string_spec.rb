require 'spec_helper'

describe 'Lexer string' do
  it "lexes simple string" do
    lexer = Lexer.new(%("hello"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('hello')

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with newline" do
    lexer = Lexer.new(%("hello\\nworld"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("\n")

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("world")

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with n" do
    lexer = Lexer.new(%("fun"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('fun')

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with slash" do
    lexer = Lexer.new(%("hello\\world"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('hello')

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("\\")

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('world')

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with slash quote" do
    lexer = Lexer.new(%("\\""))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('"')

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with slash quote" do
    lexer = Lexer.new(%("\\t"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("\t")

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with interpolation" do
    lexer = Lexer.new(%("hello \#{world}"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_string_token
    token.type.should eq(:INTERPOLATION_START)

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    token = lexer.next_token
    token.type.should eq(:'}')

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end

  it "lexes string with numeral" do
    lexer = Lexer.new(%("hello#world"))

    token = lexer.next_token
    token.type.should eq(:STRING_START)

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('hello')

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq("#")

    token = lexer.next_string_token
    token.type.should eq(:STRING)
    token.value.should eq('world')

    token = lexer.next_string_token
    token.type.should eq(:STRING_END)
  end
end
