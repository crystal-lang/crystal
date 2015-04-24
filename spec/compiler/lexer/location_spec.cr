require "../../spec_helper"

private def assert_token_column_number(lexer, type, column_number)
  token = lexer.next_token
  expect(token.type).to eq(type)
  expect(token.column_number).to eq(column_number)
end

describe "Lexer: location" do
  it "stores line numbers" do
    lexer = Lexer.new "1\n2"
    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.line_number).to eq(1)

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.line_number).to eq(1)

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.line_number).to eq(2)
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
    expect(token.type).to eq(:NUMBER)
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(1)
    expect(token.filename).to eq("bar")

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(2)

    token = lexer.next_token
    expect(token.type).to eq(:"+")
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(3)

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)
    expect(token.line_number).to eq(1)
    expect(token.column_number).to eq(4)

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.line_number).to eq(12)
    expect(token.column_number).to eq(34)
    expect(token.filename).to eq("foo")
  end

  it "assigns correct loc location to node" do
    exps = Parser.parse(%[(#<loc:"foo.txt",2,3>1 + 2)]) as Expressions
    node = exps.expressions.first
    location = node.location.not_nil!
    expect(location.line_number).to eq(2)
    expect(location.column_number).to eq(3)
    expect(location.filename).to eq("foo.txt")
  end

  it "parses var/call right after loc (#491)" do
    exps = Parser.parse(%[(#<loc:"foo.txt",2,3>msg)]) as Expressions
    exp = exps.expressions.first as Call
    expect(exp.name).to eq("msg")
  end
end
