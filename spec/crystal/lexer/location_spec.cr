#!/usr/bin/env bin/crystal -run
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
end
