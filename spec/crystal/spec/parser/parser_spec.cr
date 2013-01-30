#!/usr/bin/env bin/crystal -run
require "spec"
require "../../../../bootstrap/crystal/parser"
require "../../../../bootstrap/crystal/to_s"

include Crystal

class Numeric
  def int
    IntLiteral.new to_s
  end

  def long
    LongLiteral.new to_s
  end

  def float
    FloatLiteral.new to_f.to_s
  end

  def double
    DoubleLiteral.new to_d.to_s
  end
end

class Bool
  def bool
    BoolLiteral.new self
  end
end

class Array
  def array
    ArrayLiteral.new self
  end

  def ident
    Ident.new self
  end
end

class String
  def var
    Var.new self
  end

  def arg
    Arg.new self
  end

  def call
    Call.new nil, self
  end

  def call(args)
    Call.new nil, self, args
  end

  def ident
    Ident.new [self]
  end
end

def it_parses(string, expected_node)
  it "parses #{string}" do
    node = Parser.parse(string)
    node.should eq(Expressions.from expected_node)
  end
end

include Crystal

describe "Parser" do
  it_parses "nil", NilLiteral.new

  it_parses "true", true.bool
  it_parses "false", false.bool

  it_parses "1", 1.int
  it_parses "+1", 1.int
  it_parses "-1", -1.int

  it_parses "1L", 1.long
  it_parses "+1L", 1.long
  it_parses "-1L", -1.long

  it_parses "1.0", 1.0.double
  it_parses "+1.0", 1.0.double
  it_parses "-1.0", -1.0.double

  it_parses "1.0f", 1.0.float
  it_parses "+1.0f", 1.0.float
  it_parses "-1.0f", -1.0.float

  it_parses "'a'", CharLiteral.new("a")

  it_parses "\"foo\"", StringLiteral.new("foo")
  it_parses "\"\"", StringLiteral.new("")

  it_parses ":foo", SymbolLiteral.new("foo")

  it_parses "[]", [].array
  it_parses "[1, 2]", [1.int, 2.int].array
  it_parses "[\n1, 2]", [1.int, 2.int].array
  it_parses "[1,\n 2,]", [1.int, 2.int].array

  it_parses "1 + 2", Call.new(1.int, "+", [2.int])
  it_parses "1 +\n2", Call.new(1.int, "+", [2.int])
  it_parses "1 +2", Call.new(1.int, "+", [2.int])
  it_parses "1 -2", Call.new(1.int, "-", [2.int])
  it_parses "1 +2.0", Call.new(1.int, "+", [2.double])
  it_parses "1 -2.0", Call.new(1.int, "-", [2.double])
  it_parses "1 +2L", Call.new(1.int, "+", [2.long])
  it_parses "1 -2L", Call.new(1.int, "-", [2.long])
  it_parses "1\n+2", [1.int, 2.int]
  it_parses "1;+2", [1.int, 2.int]
  it_parses "1 - 2", Call.new(1.int, "-", [2.int])
  it_parses "1 -\n2", Call.new(1.int, "-", [2.int])
  it_parses "1\n-2", [1.int, -2.int]
  it_parses "1;-2", [1.int, -2.int]
  it_parses "1 * 2", Call.new(1.int, "*", [2.int])
  it_parses "1 * -2", Call.new(1.int, "*", [-2.int])
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int, "*", [3.int]), "+", [Call.new(4.int, "*", [5.int])])
  it_parses "1 / 2", Call.new(1.int, "/", [2.int])
  it_parses "1 / -2", Call.new(1.int, "/", [-2.int])
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int, "/", [3.int]), "+", [Call.new(4.int, "/", [5.int])])
  it_parses "2 * (3 + 4)", Call.new(2.int, "*", [Call.new(3.int, "+", [4.int])])

  it_parses "!1", Call.new(1.int, "!@")
  it_parses "1 && 2", And.new(1.int, 2.int)
  it_parses "1 || 2", Or.new(1.int, 2.int)

  it_parses "1 <=> 2", Call.new(1.int, "<=>", [2.int])

  it_parses "a = 1", Assign.new("a".var, 1.int)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int))

  # it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var], [1.int, 2.int])
  # it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var], [1.int])
  # it_parses "a = 1, 2", MultiAssign.new(["a".var], [1.int, 2.int])

  it_parses "def foo\n1\nend", Def.new("foo", [], [1.int])
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".arg], [1.int])
  it_parses "def foo ; 1 ; end", Def.new("foo", [], [1.int])
  it_parses "def foo; end", Def.new("foo", [], nil)
  it_parses "def foo(var); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar\n); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(var1, var2); end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var; end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var\n end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var1, var2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var1,\nvar2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo; 1; 2; end", Def.new("foo", [], [1.int, 2.int])
  it_parses "def foo=(value); end", Def.new("foo=", ["value".arg], [])
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".arg], "foo".call([Call.new("n".var, "-", [1.int])]))
  it_parses "def type(type); end", Def.new("type", ["type".arg], nil)

  it_parses "def self.foo\n1\nend", Def.new("foo", [], [1.int], "self".var)
  it_parses "def Foo.foo\n1\nend", Def.new("foo", [], [1.int], "Foo".ident)
  it_parses "def Foo::Bar.foo\n1\nend", Def.new("foo", [], [1.int], ["Foo", "Bar"].ident)

  it_parses "def foo; a; end", Def.new("foo", [], ["a".call])
  it_parses "def foo(a); a; end", Def.new("foo", ["a".arg], ["a".var])
  it_parses "def foo; a = 1; a; end", Def.new("foo", [], [Assign.new("a".var, 1.int), "a".var])
  it_parses "def foo; a = 1; a {}; end", Def.new("foo", [], [Assign.new("a".var, 1.int), Call.new(nil, "a", [], Block.new)])
  it_parses "def foo; a = 1; x { a }; end", Def.new("foo", [], [Assign.new("a".var, 1.int), Call.new(nil, "x", [], Block.new([], ["a".var]))])
  it_parses "def foo; x { |a| a }; end", Def.new("foo", [], [Call.new(nil, "x", [], Block.new(["a".var], ["a".var]))])

  it_parses "def foo(var = 1); end", Def.new("foo", [Arg.new("var", 1.int)], nil)
  it_parses "def foo var = 1; end", Def.new("foo", [Arg.new("var", 1.int)], nil)
  it_parses "def foo(var : Int); end", Def.new("foo", [Arg.new("var", nil, "Int".ident)], nil)
  it_parses "def foo var : Int; end", Def.new("foo", [Arg.new("var", nil, "Int".ident)], nil)
  it_parses "def foo(var : self); end", Def.new("foo", [Arg.new("var", nil, SelfRestriction.new)], nil)
  it_parses "def foo var : self; end", Def.new("foo", [Arg.new("var", nil, SelfRestriction.new)], nil)
  it_parses "def foo; yield; end", Def.new("foo", [], [Yield.new], nil, true)

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call([1.int])
  it_parses "foo 1", "foo".call([1.int])
  it_parses "foo 1\n", "foo".call([1.int])
  it_parses "foo 1;", "foo".call([1.int])
  it_parses "foo 1, 2", "foo".call([1.int, 2.int])
  it_parses "foo (1 + 2), 3", "foo".call([Call.new(1.int, "+", [2.int]), 3.int])
  it_parses "foo(1 + 2)", "foo".call([Call.new(1.int, "+", [2.int])])
  it_parses "foo -1.0, -2.0", "foo".call([-1.double, -2.double])
  it_parses "foo(\n1)", "foo".call([1.int])

  it_parses "foo + 1", Call.new("foo".call, "+", [1.int])
  it_parses "foo +1", Call.new(nil, "foo", [1.int])
  it_parses "foo +1.0", Call.new(nil, "foo", [1.double])
  it_parses "foo +1L", Call.new(nil, "foo", [1.long])
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int), Call.new("foo".var, "+", [1.int])]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int), Call.new("foo".var, "-", [1.int])]

  it_parses "foo !false", Call.new(nil, "foo", [Call.new(false.bool, "!@")])
  it_parses "!a && b", And.new(Call.new("a".call, "!@"), "b".call)

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".ident, "new")])
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".ident, "new")])
  it_parses "f.x = - 1", Call.new("f".call, "x=", [Call.new(1.int, "-@")])

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "f.x #{op}= 2", Call.new("f".call, "x=", [Call.new(Call.new("f".call, "x"), op, [2.int])])
  end

  ["/", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "%", "&", "|", "^", "**", "+@", "-@", "~@", "!@", "==="].each do |op|
    it_parses "def #{op}; end;", Def.new(op, [], nil)
  end

  ["<<", "<", "<=", "==", ">>", ">", ">=", "+", "-", "*", "/", "%", "|", "&", "^", "**", "==="].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int, op, [2.int])
    it_parses "n #{op} 2", Call.new("n".call, op, [2.int])
  end

  ["bar", "+", "-", "*", "/", "<", "<=", "==", ">", ">=", "%", "|", "&", "^", "**", "==="].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, [1.int, 2.int])
  end

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "a = 1; a #{op}= 1", [Assign.new("a".var, 1.int), Assign.new("a".var, Call.new("a".var, op, [1.int]))]
  end

  it_parses "a = 1; a &&= 1", [Assign.new("a".var, 1.int), Assign.new("a".var, And.new("a".var, 1.int))]
  it_parses "a = 1; a ||= 1", [Assign.new("a".var, 1.int), Assign.new("a".var, Or.new("a".var, 1.int))]

  it_parses "if foo; 1; end", If.new("foo".call, 1.int)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int, 2.int)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int, 2.int)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int, If.new("bar".call, 2.int, 3.int))

  it_parses "include Foo", Include.new("Foo".ident)
  it_parses "include Foo\nif true; end", [Include.new("Foo".ident), If.new(true.bool)]
end
