#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Lexer regexp" do
  it "lexes without modifiers" do
    lexer = Lexer.new("/foo/")
    token = lexer.next_token
    token.regexp_modifiers.should eq(0)
  end

  it "lexes with modifier i" do
    lexer = Lexer.new("/foo/i")
    token = lexer.next_token
    token.regexp_modifiers.should eq(Regexp::IGNORE_CASE)
  end

  it "lexes with modifier m" do
    lexer = Lexer.new("/foo/m")
    token = lexer.next_token
    token.regexp_modifiers.should eq(Regexp::MULTILINE)
  end

  it "lexes with modifier x" do
    lexer = Lexer.new("/foo/x")
    token = lexer.next_token
    token.regexp_modifiers.should eq(Regexp::EXTENDED)
  end

  it "lexes with all modifiers" do
    lexer = Lexer.new("/foo/imximximx")
    token = lexer.next_token
    token.regexp_modifiers.should eq(Regexp::IGNORE_CASE | Regexp::MULTILINE | Regexp::EXTENDED)
  end
end
