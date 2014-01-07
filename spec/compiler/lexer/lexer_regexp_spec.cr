#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Lexer regex" do
  it "lexes without modifiers" do
    lexer = Lexer.new("/foo/")
    token = lexer.next_token
    token.regex_modifiers.should eq(0)
  end

  it "lexes with modifier i" do
    lexer = Lexer.new("/foo/i")
    token = lexer.next_token
    token.regex_modifiers.should eq(Regex::IGNORE_CASE)
  end

  it "lexes with modifier m" do
    lexer = Lexer.new("/foo/m")
    token = lexer.next_token
    token.regex_modifiers.should eq(Regex::MULTILINE)
  end

  it "lexes with modifier x" do
    lexer = Lexer.new("/foo/x")
    token = lexer.next_token
    token.regex_modifiers.should eq(Regex::EXTENDED)
  end

  it "lexes with all modifiers" do
    lexer = Lexer.new("/foo/imximximx")
    token = lexer.next_token
    token.regex_modifiers.should eq(Regex::IGNORE_CASE | Regex::MULTILINE | Regex::EXTENDED)
  end
end
