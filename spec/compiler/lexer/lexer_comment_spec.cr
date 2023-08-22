require "../../support/syntax"

private def t(kind : Crystal::Token::Kind)
  kind
end

describe "Lexer comments" do
  it "lexes without comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))

    token = lexer.next_token
    token.type.should eq(t :NEWLINE)

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
  end

  it "lexes with comments enabled" do
    lexer = Lexer.new(%(# Hello\n1))
    lexer.comments_enabled = true

    token = lexer.next_token
    token.type.should eq(t :COMMENT)
    token.value.should eq("# Hello")

    token = lexer.next_token
    token.type.should eq(t :NEWLINE)

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
  end

  it "lexes with comments enabled (2)" do
    lexer = Lexer.new(%(1 # Hello))
    lexer.comments_enabled = true

    token = lexer.next_token
    token.type.should eq(t :NUMBER)

    token = lexer.next_token
    token.type.should eq(t :SPACE)

    token = lexer.next_token
    token.type.should eq(t :COMMENT)
    token.value.should eq("# Hello")

    token = lexer.next_token
    token.type.should eq(t :EOF)
  end

  it "lexes correct number of spaces" do
    lexer = Lexer.new(%(1   2))
    lexer.count_whitespace = true

    token = lexer.next_token
    token.type.should eq(t :NUMBER)

    token = lexer.next_token
    token.type.should eq(t :SPACE)
    token.value.should eq("   ")

    token = lexer.next_token
    token.type.should eq(t :NUMBER)

    token = lexer.next_token
    token.type.should eq(t :EOF)
  end
end
