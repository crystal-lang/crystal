require "../../spec_helper"

describe "Lexer string array" do
  it "lexes simple string array" do
    lexer = Lexer.new("%w(one two)")

    token = lexer.next_token
    token.type.should eq(:STRING_ARRAY_START)

    token = lexer.next_string_array_token
    token.type.should eq(:STRING)
    token.value.should eq("one")

    token = lexer.next_string_array_token
    token.type.should eq(:STRING)
    token.value.should eq("two")

    token = lexer.next_string_array_token
    token.type.should eq(:STRING_ARRAY_END)
  end

  it "lexes string array with new line" do
    lexer = Lexer.new("%w(one \n two)")

    token = lexer.next_token
    token.type.should eq(:STRING_ARRAY_START)

    token = lexer.next_string_array_token
    token.type.should eq(:STRING)
    token.value.should eq("one")

    token = lexer.next_string_array_token
    token.type.should eq(:STRING)
    token.value.should eq("two")

    token = lexer.next_string_array_token
    token.type.should eq(:STRING_ARRAY_END)
  end

  it "lexes string array with new line gives correct column for next token" do
    lexer = Lexer.new("%w(one \n two).")

    lexer.next_token
    lexer.next_string_array_token
    lexer.next_string_array_token
    lexer.next_string_array_token

    token = lexer.next_token
    token.line_number.should eq(2)
    token.column_number.should eq(6)
  end
end
