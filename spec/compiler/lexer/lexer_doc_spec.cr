require "../../spec_helper"

describe "Lexer doc" do
  it "lexes without doc enabled" do
    lexer = Lexer.new(%(1))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to be_nil
  end

  it "lexes with doc enabled but without docs" do
    lexer = Lexer.new(%(1))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to be_nil
  end

  it "lexes with doc enabled and docs" do
    lexer = Lexer.new(%(# hello\n1))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("hello")

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to eq("hello")
  end

  it "lexes with doc enabled and docs, two line comment" do
    lexer = Lexer.new(%(# hello\n# world\n1))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("hello")

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("hello\nworld")
  end

  it "lexes with doc enabled and docs, two line comment with leading whitespace" do
    lexer = Lexer.new(%(# hello\n    # world\n1))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("hello")

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)
    expect(token.doc).to eq("hello")

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("hello\nworld")

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to eq("hello\nworld")
  end

  it "lexes with doc enabled and docs, one line comment with two newlines and another comment" do
    lexer = Lexer.new(%(# hello\n\n    # world\n1))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to be_nil

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)
    expect(token.doc).to be_nil

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("world")

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to eq("world")
  end

  it "resets doc after non newline or space token" do
    lexer = Lexer.new(%(# hello\n1 2))
    lexer.doc_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)
    expect(token.doc).to eq("hello")

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to eq("hello")

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)
    expect(token.doc).to be_nil

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
    expect(token.doc).to be_nil
  end
end
