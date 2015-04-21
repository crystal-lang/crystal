require "../../spec_helper"

private def it_should_be_valid_string_array_lexer(lexer)
  token = lexer.next_token
  expect(token.type).to eq(:STRING_ARRAY_START)

  token = lexer.next_string_array_token
  expect(token.type).to eq(:STRING)
  expect(token.value).to eq("one")

  token = lexer.next_string_array_token
  expect(token.type).to eq(:STRING)
  expect(token.value).to eq("two")

  token = lexer.next_string_array_token
  expect(token.type).to eq(:STRING_ARRAY_END)
end

describe "Lexer string array" do
  it "lexes simple string array" do
    lexer = Lexer.new("%w(one two)")

    it_should_be_valid_string_array_lexer(lexer)
  end

  it "lexes string array with new line" do
    lexer = Lexer.new("%w(one \n two)")

    token = lexer.next_token
    expect(token.type).to eq(:STRING_ARRAY_START)

    token = lexer.next_string_array_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq("one")

    token = lexer.next_string_array_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq("two")

    token = lexer.next_string_array_token
    expect(token.type).to eq(:STRING_ARRAY_END)
  end

  it "lexes string array with new line gives correct column for next token" do
    lexer = Lexer.new("%w(one \n two).")

    lexer.next_token
    lexer.next_string_array_token
    lexer.next_string_array_token
    lexer.next_string_array_token

    token = lexer.next_token
    expect(token.line_number).to eq(2)
    expect(token.column_number).to eq(6)
  end

  context "using { as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w{one two}")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using [ as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w[one two]")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using < as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w<one two>")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

end
