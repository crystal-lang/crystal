require "spec"
require "ecr"

describe "ECR::Lexer" do
  it "lexes without interpolation" do
    lexer = ECR::Lexer.new("hello")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("hello")
    token.line_number.should eq(1)
    token.column_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes with <% %>" do
    lexer = ECR::Lexer.new("hello <% foo %> bar")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("hello ")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:CONTROL)
    token.value.should eq(" foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(9)

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq(" bar")
    token.line_number.should eq(1)
    token.column_number.should eq(16)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes with <%= %>" do
    lexer = ECR::Lexer.new("hello <%= foo %> bar")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_token
    token.type.should eq(:OUTPUT)
    token.value.should eq(" foo ")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq(" bar")

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes with <% %> and correct location info" do
    lexer = ECR::Lexer.new("hi\nthere <% foo\nbar %> baz")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("hi\nthere ")
    token.line_number.should eq(1)
    token.column_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:CONTROL)
    token.value.should eq(" foo\nbar ")
    token.line_number.should eq(2)
    token.column_number.should eq(9)

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq(" baz")
    token.line_number.should eq(3)
    token.column_number.should eq(7)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end
end
