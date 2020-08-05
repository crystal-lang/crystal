require "../../support/syntax"

private def assert_token_column_number(lexer, type, column_number)
  token = lexer.next_token
  token.type.should eq(type)
  token.column_number.should eq(column_number)
end

describe "Lexer: location" do
  it "stores line numbers" do
    lexer = Lexer.new "1\n2"
    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(2)
  end

  it "stores column numbers" do
    lexer = Lexer.new "1;  ident; def;\n4"
    assert_token_column_number lexer, :NUMBER, 1
    assert_token_column_number lexer, :";", 2
    assert_token_column_number lexer, :SPACE, 3
    assert_token_column_number lexer, :IDENT, 5
    assert_token_column_number lexer, :";", 10
    assert_token_column_number lexer, :SPACE, 11
    assert_token_column_number lexer, :IDENT, 12
    assert_token_column_number lexer, :";", 15
    assert_token_column_number lexer, :NEWLINE, 16
    assert_token_column_number lexer, :NUMBER, 1
  end

  it "overrides location with pragma" do
    lexer = Lexer.new %(1 + #<loc:"foo",12,34>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(1)
    token.filename.should eq("bar")

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.line_number.should eq(1)
    token.column_number.should eq(2)

    token = lexer.next_token
    token.type.should eq(:"+")
    token.line_number.should eq(1)
    token.column_number.should eq(3)

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.line_number.should eq(1)
    token.column_number.should eq(4)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(12)
    token.column_number.should eq(34)
    token.filename.should eq("foo")
  end

  it "pushes and pops its location" do
    lexer = Lexer.new %(#<loc:push>#<loc:"foo",12,34>1 + #<loc:pop>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(12)
    token.column_number.should eq(34)
    token.filename.should eq("foo")

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.line_number.should eq(12)
    token.column_number.should eq(35)

    token = lexer.next_token
    token.type.should eq(:"+")
    token.line_number.should eq(12)
    token.column_number.should eq(36)

    token = lexer.next_token
    token.type.should eq(:SPACE)
    token.line_number.should eq(12)
    token.column_number.should eq(37)

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(44)
    token.filename.should eq("bar")
  end

  it "uses two consecutive loc pragma " do
    lexer = Lexer.new %(1#<loc:"foo",12,34>#<loc:"foo",56,78>2)
    lexer.filename = "bar"

    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.line_number.should eq(1)
    token.column_number.should eq(1)
    token.filename.should eq("bar")

    token = lexer.next_token
    token.type.should eq(:NUMBER)
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

  it "locations with virtual files shoud be comparable" do
    loc1 = Location.new("file1", 1, 1)
    loc2 = Location.new(VirtualFile.new(Macro.new("macro", [] of Arg, Nop.new), "", Location.new("f", 1, 1)), 2, 1)
    (loc1 < loc2).should be_false
    (loc2 < loc1).should be_false
  end
end
