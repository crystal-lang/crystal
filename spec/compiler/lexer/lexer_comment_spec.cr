require "../../spec_helper"

describe "Lexer comments" do
  it "lexes line comments without comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))

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

  it "lexes with comments enabled (2)" do
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

  it "lexes block comments without comments enabled" do
    lexer = Lexer.new(%(1#[\n2\n3\n#]4))

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.value.should eq("1")

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.value.should eq("4")

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes block comments with comments enabled" do
    lexer = Lexer.new(%(1#[\n2\n3\n#]4))
    lexer.comments_enabled = true

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.value.should eq("1")

    token = lexer.next_token
    token.type.should eq(:COMMENT)
    token.value.should eq("#[\n2\n3\n#]")

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.value.should eq("4")
  end
end
