require "spec"
require "ecr"

describe "ECR::Lexer" do
  it "lexes without interpolation" do
    lexer = ECR::Lexer.new("hello")

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq("hello")
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(1)

    token = lexer.next_token
    expect(token.type).to eq(:EOF)
  end

  it "lexes with <% %>" do
    lexer = ECR::Lexer.new("hello <% foo %> bar")

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq("hello ")
    expect(token.column_number).to eq(1)
    expect(token.line_number).to eq(1)

    token = lexer.next_token
    expect(token.type).to eq(:CONTROL)
    expect(token.value).to eq(" foo ")
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(9)

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq(" bar")
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(16)

    token = lexer.next_token
    expect(token.type).to eq(:EOF)
  end

  it "lexes with <%= %>" do
    lexer = ECR::Lexer.new("hello <%= foo %> bar")

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq("hello ")

    token = lexer.next_token
    expect(token.type).to eq(:OUTPUT)
    expect(token.value).to eq(" foo ")

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq(" bar")

    token = lexer.next_token
    expect(token.type).to eq(:EOF)
  end

  it "lexes with <% %> and correct location info" do
    lexer = ECR::Lexer.new("hi\nthere <% foo\nbar %> baz")

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq("hi\nthere ")
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(1)

    token = lexer.next_token
    expect(token.type).to eq(:CONTROL)
    expect(token.value).to eq(" foo\nbar ")
    expect(token.line_number).to eq(2)
    expect(token.column_number).to eq(9)

    token = lexer.next_token
    expect(token.type).to eq(:STRING)
    expect(token.value).to eq(" baz")
    expect(token.line_number).to eq(3)
    expect(token.column_number).to eq(7)

    token = lexer.next_token
    expect(token.type).to eq(:EOF)
  end
end
