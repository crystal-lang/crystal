#!/usr/bin/env bin/crystal --run
require "spec"
require "ecr"

describe "ECR::Lexer" do
  it "lexes without interpolation" do
    lexer = ECR::Lexer.new("hello")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("hello")

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes with <% %>" do
    lexer = ECR::Lexer.new("hello <% foo %> bar")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("hello ")

    token = lexer.next_token
    token.type.should eq(:CONTROL)
    token.value.should eq(" foo ")

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq(" bar")

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
end
