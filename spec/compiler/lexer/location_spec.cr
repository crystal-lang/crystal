require "../../spec_helper"

def assert_token_column_number(lexer, type, column_number)
  token = lexer.next_token
  token.type.should eq(type)
  token.column_number.should eq(column_number)
end

describe "Lexer: location" do
  it "stores line numbers" do
    lexer = Lexer.new "1\n2"
    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(2)
  end

  it "stores column numbers" do
    lexer = Lexer.new "1;  ident; def;\n4"
    assert_token_column_number lexer, :NUMBER, 1
    assert_token_column_number lexer, :";", 2
    assert_token_column_number lexer, :SPACE, 3
    assert_token_column_number lexer, :IDENT, 5
    assert_token_column_number lexer, :";", 10
    assert_token_column_number lexer, :SPACE, 11
    assert_token_column_number lexer, :IDENT, 12
    assert_token_column_number lexer, :";", 15
    assert_token_column_number lexer, :NEWLINE, 16
    assert_token_column_number lexer, :NUMBER, 1
  end

  it "overrides location with pragma" do
    lexer = Lexer.new %(1 + #<loc:"foo",12,34>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(1)
    token.filename.should eq("bar")

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.line_number.should eq(1)
    token.column_number.should eq(2)

    token = lexer.next_token
    token.type.should eq(:"+")
    token.line_number.should eq(1)
    token.column_number.should eq(3)

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.line_number.should eq(1)
    token.column_number.should eq(4)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(12)
    token.column_number.should eq(34)
    token.filename.should eq("foo")
  end

  it "assigns correct loc location to node" do
    node = Parser.parse(%[(#<loc:"foo.txt",2,3>1 + 2)])
    location = node.location.not_nil!
    location.line_number.should eq(2)
    location.column_number.should eq(3)
    location.filename.should eq("foo.txt")
  end
end
