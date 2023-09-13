require "../../support/syntax"

private def t(kind : Crystal::Token::Kind)
  kind
end

private def assert_token_column_number(lexer, type : Token::Kind, column_number)
  token = lexer.next_token
  token.type.should eq(type)
  token.column_number.should eq(column_number)
end

describe "Lexer: location" do
  it "stores line numbers" do
    lexer = Lexer.new "1\n2"
    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :NEWLINE)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(2)
  end

  it "stores column numbers" do
    lexer = Lexer.new "1;  ident; def;\n4"
    assert_token_column_number lexer, :NUMBER, 1
    assert_token_column_number lexer, :OP_SEMICOLON, 2
    assert_token_column_number lexer, :SPACE, 3
    assert_token_column_number lexer, :IDENT, 5
    assert_token_column_number lexer, :OP_SEMICOLON, 10
    assert_token_column_number lexer, :SPACE, 11
    assert_token_column_number lexer, :IDENT, 12
    assert_token_column_number lexer, :OP_SEMICOLON, 15
    assert_token_column_number lexer, :NEWLINE, 16
    assert_token_column_number lexer, :NUMBER, 1
  end

  it "overrides location with pragma" do
    lexer = Lexer.new %(1 + #<loc:"foo",12,34>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(1)
    token.filename.should eq("bar")

    token = lexer.next_token
    token.type.should eq(t :SPACE)
    token.line_number.should eq(1)
    token.column_number.should eq(2)

    token = lexer.next_token
    token.type.should eq(t :OP_PLUS)
    token.line_number.should eq(1)
    token.column_number.should eq(3)

    token = lexer.next_token
    token.type.should eq(t :SPACE)
    token.line_number.should eq(1)
    token.column_number.should eq(4)

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(12)
    token.column_number.should eq(34)
    token.filename.should eq("foo")
  end

  it "pushes and pops its location" do
    lexer = Lexer.new %(#<loc:push>#<loc:"foo",12,34>1 + #<loc:pop>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(12)
    token.column_number.should eq(34)
    token.filename.should eq("foo")

    token = lexer.next_token
    token.type.should eq(t :SPACE)
    token.line_number.should eq(12)
    token.column_number.should eq(35)

    token = lexer.next_token
    token.type.should eq(t :OP_PLUS)
    token.line_number.should eq(12)
    token.column_number.should eq(36)

    token = lexer.next_token
    token.type.should eq(t :SPACE)
    token.line_number.should eq(12)
    token.column_number.should eq(37)

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(44)
    token.filename.should eq("bar")
  end

  it "uses two consecutive loc pragma " do
    lexer = Lexer.new %(1#<loc:"foo",12,34>#<loc:"foo",56,78>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(1)
    token.filename.should eq("bar")

    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.line_number.should eq(56)
    token.column_number.should eq(78)
    token.filename.should eq("foo")
  end

  it "assigns correct loc location to node" do
    exps = Parser.parse(%[(#<loc:"foo.txt",2,3>1 + 2)]).as(Expressions)
    node = exps.expressions.first
    location = node.location.not_nil!
    location.line_number.should eq(2)
    location.column_number.should eq(3)
    location.filename.should eq("foo.txt")
  end

  it "parses var/call right after loc (#491)" do
    exps = Parser.parse(%[(#<loc:"foo.txt",2,3>msg)]).as(Expressions)
    exp = exps.expressions.first.as(Call)
    exp.name.should eq("msg")
  end

  it "locations in different files have no order" do
    loc1 = Location.new("file1", 1, 1)
    loc2 = Location.new("file2", 2, 2)

    (loc1 < loc2).should be_false
    (loc1 <= loc2).should be_false

    (loc1 > loc2).should be_false
    (loc1 >= loc2).should be_false
  end

  it "locations in same files are comparable based on line" do
    loc1 = Location.new("file1", 1, 1)
    loc2 = Location.new("file1", 2, 1)
    loc3 = Location.new("file1", 1, 1)
    (loc1 < loc2).should be_true
    (loc1 <= loc2).should be_true
    (loc1 <= loc3).should be_true

    (loc2 > loc1).should be_true
    (loc2 >= loc1).should be_true
    (loc3 >= loc1).should be_true

    (loc2 < loc1).should be_false
    (loc2 <= loc1).should be_false

    (loc1 > loc2).should be_false
    (loc1 >= loc2).should be_false

    (loc3 == loc1).should be_true
  end

  it "locations with virtual files should be comparable" do
    loc1 = Location.new("file1", 1, 1)
    loc2 = Location.new(VirtualFile.new(Macro.new("macro", [] of Arg, Nop.new), "", Location.new("f", 1, 1)), 2, 1)
    (loc1 < loc2).should be_false
    (loc2 < loc1).should be_false
  end

  describe "Location.parse" do
    it "parses location from string" do
      Location.parse("foo:1:2").should eq(Location.new("foo", 1, 2))
      Location.parse("foo:bar/baz:345:6789").should eq(Location.new("foo:bar/baz", 345, 6789))
      Location.parse(%q(C:\foo\bar:1:2)).should eq(Location.new(%q(C:\foo\bar), 1, 2))
    end

    it "raises ArgumentError if missing colon" do
      expect_raises(ArgumentError, "cursor location must be file:line:column") { Location.parse("foo") }
      expect_raises(ArgumentError, "cursor location must be file:line:column") { Location.parse("foo:1") }
    end

    it "raises ArgumentError if missing part" do
      expect_raises(ArgumentError, "cursor location must be file:line:column") { Location.parse(":1:2") }
      expect_raises(ArgumentError, "cursor location must be file:line:column") { Location.parse("foo::2") }
      expect_raises(ArgumentError, "cursor location must be file:line:column") { Location.parse("foo:1:") }
    end

    it "raises ArgumentError if line number is invalid" do
      expect_raises(ArgumentError, "line must be a positive integer, not a") { Location.parse("foo:a:2") }
      expect_raises(ArgumentError, "line must be a positive integer, not 0") { Location.parse("foo:0:2") }
      expect_raises(ArgumentError, "line must be a positive integer, not -1") { Location.parse("foo:-1:2") }
    end

    it "raises ArgumentError if column number is invalid" do
      expect_raises(ArgumentError, "column must be a positive integer, not a") { Location.parse("foo:2:a") }
      expect_raises(ArgumentError, "column must be a positive integer, not 0") { Location.parse("foo:2:0") }
      expect_raises(ArgumentError, "column must be a positive integer, not -1") { Location.parse("foo:2:-1") }
    end
  end
end
