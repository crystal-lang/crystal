require "spec"
require "csv"

class CSV::Lexer
  def expect_cell(value, file = __FILE__, line = __LINE__)
    token = next_token
    token.kind.should eq(CSV::Token::Kind::Cell), file, line
    token.value.should eq(value), file, line
  end

  def expect_eof(file = __FILE__, line = __LINE__)
    next_token.kind.should eq(CSV::Token::Kind::Eof), file, line
  end

  def expect_newline(file = __FILE__, line = __LINE__)
    next_token.kind.should eq(CSV::Token::Kind::Newline), file, line
  end
end

describe CSV do
  describe "lex" do
    it "lexes two columns" do
      lexer = CSV::Lexer.new("hello,world")
      lexer.expect_cell "hello"
      lexer.expect_cell "world"
      lexer.expect_eof
    end

    it "lexes two columns with two rows" do
      lexer = CSV::Lexer.new("hello,world\nfoo,bar")
      lexer.expect_cell "hello"
      lexer.expect_cell "world"
      lexer.expect_newline
      lexer.expect_cell "foo"
      lexer.expect_cell "bar"
      lexer.expect_eof
    end

    it "lexes two columns with two rows with \r\n" do
      lexer = CSV::Lexer.new("hello,world\r\nfoo,bar")
      lexer.expect_cell "hello"
      lexer.expect_cell "world"
      lexer.expect_newline
      lexer.expect_cell "foo"
      lexer.expect_cell "bar"
      lexer.expect_eof
    end

    it "lexes two empty columns" do
      lexer = CSV::Lexer.new(",")
      lexer.expect_cell ""
      lexer.expect_cell ""
      lexer.expect_eof
    end

    it "lexes last empty column" do
      lexer = CSV::Lexer.new("foo,")
      lexer.expect_cell "foo"
      lexer.expect_cell ""
      lexer.expect_eof
    end

    it "lexes with empty columns" do
      lexer = CSV::Lexer.new("foo,,bar")
      lexer.expect_cell "foo"
      lexer.expect_cell ""
      lexer.expect_cell "bar"
      lexer.expect_eof
    end

    it "lexes with whitespace" do
      lexer = CSV::Lexer.new("  foo  ,  bar  ")
      lexer.expect_cell "  foo  "
      lexer.expect_cell "  bar  "
      lexer.expect_eof
    end

    it "lexes two with quotes" do
      lexer = CSV::Lexer.new(%("hello","world"))
      lexer.expect_cell "hello"
      lexer.expect_cell "world"
      lexer.expect_eof
    end

    it "lexes two with inner quotes" do
      lexer = CSV::Lexer.new(%("hel""lo","wor""ld"))
      lexer.expect_cell %(hel"lo)
      lexer.expect_cell %(wor"ld)
      lexer.expect_eof
    end

    it "lexes with comma inside quote" do
      lexer = CSV::Lexer.new(%("foo,bar"))
      lexer.expect_cell "foo,bar"
      lexer.expect_eof
    end

    it "lexes with newline inside quote" do
      lexer = CSV::Lexer.new(%("foo\nbar"))
      lexer.expect_cell "foo\nbar"
      lexer.expect_eof
    end

    it "lexes newline and eof as a single eof" do
      lexer = CSV::Lexer.new("hello,world\n")
      lexer.expect_cell "hello"
      lexer.expect_cell "world"
      lexer.expect_eof
    end

    it "lexes with a given separator" do
      lexer = CSV::Lexer.new("hello;world\n", separator: ';')
      lexer.expect_cell "hello"
      lexer.expect_cell "world"
      lexer.expect_eof
    end

    it "lexes with a given quote char" do
      lexer = CSV::Lexer.new("'hello,world'\n", quote_char: '\'')
      lexer.expect_cell "hello,world"
      lexer.expect_eof
    end

    it "raises if single quote in the middle" do
      expect_raises CSV::MalformedCSVError, "Unexpected quote at 1:4" do
        lexer = CSV::Lexer.new %(hel"lo)
        lexer.next_token
      end
    end

    it "raises if command, newline or end doesn't follow quote" do
      expect_raises CSV::MalformedCSVError, "Expecting comma, newline or end, not 'a' at 1:6" do
        lexer = CSV::Lexer.new %("hel"a)
        lexer.next_token
      end
    end

    it "raises on unclosed quote" do
      expect_raises CSV::MalformedCSVError, "Unclosed quote at 1:5" do
        lexer = CSV::Lexer.new %("foo)
        lexer.next_token
      end
    end
  end
end
