require "../../spec_helper"

describe "Lexer comments" do
  it "lexes without comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
  end

  it "lexes with comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))
    lexer.comments_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:COMMENT)
    expect(token.value).to eq("# Hello")

    token = lexer.next_token
    expect(token.type).to eq(:NEWLINE)

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)
  end

  it "lexes with comments enabled (2)" do
    lexer = Lexer.new(%(1 # Hello))
    lexer.comments_enabled = true

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)

    token = lexer.next_token
    expect(token.type).to eq(:COMMENT)
    expect(token.value).to eq("# Hello")

    token = lexer.next_token
    expect(token.type).to eq(:EOF)
  end

  it "lexes correct number of spaces" do
    lexer = Lexer.new(%(1   2))
    lexer.count_whitespace = true

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)

    token = lexer.next_token
    expect(token.type).to eq(:SPACE)
    expect(token.value).to eq("   ")

    token = lexer.next_token
    expect(token.type).to eq(:NUMBER)

    token = lexer.next_token
    expect(token.type).to eq(:EOF)
  end
end
