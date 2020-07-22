require "../../support/syntax"

describe "Lexer comments" do
  it "lexes line comments without comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))

    token = lexer.next_token
    token.type.should eq(:NEWLINE)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
  end

  it "lexes multiline comments without comments enabled" do
    lexer = Lexer.new(%(#[ Hello\nWorld ]#\n1))

    token = lexer.next_token
    token.type.should eq(:NEWLINE)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
  end

  it "lexes line comments with comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))
    lexer.comments_enabled = true

    token = lexer.next_token
    token.type.should eq(:COMMENT)
    token.value.should eq("# Hello")

    token = lexer.next_token
    token.type.should eq(:NEWLINE)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
  end

  it "lexes multiline comments with comments enabled" do
    lexer = Lexer.new(%(#[Hello\nWorld]#\n1))
    lexer.comments_enabled = true

    token = lexer.next_token
    token.type.should eq(:COMMENT)
    token.value.should eq("#[Hello\nWorld]#")

    token = lexer.next_token
    token.type.should eq(:NEWLINE)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
  end

  it "lexes line comments with comments enabled (2)" do
    lexer = Lexer.new(%(1 # Hello))
    lexer.comments_enabled = true

    token = lexer.next_token
    token.type.should eq(:NUMBER)

    token = lexer.next_token
    token.type.should eq(:SPACE)

    token = lexer.next_token
    token.type.should eq(:COMMENT)
    token.value.should eq("# Hello")

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes correct number of spaces" do
    lexer = Lexer.new(%(1   2))
    lexer.count_whitespace = true

    token = lexer.next_token
    token.type.should eq(:NUMBER)

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.value.should eq("   ")

    token = lexer.next_token
    token.type.should eq(:NUMBER)

    token = lexer.next_token
    token.type.should eq(:EOF)
  end
end
