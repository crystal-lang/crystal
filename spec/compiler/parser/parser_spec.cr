#!/usr/bin/env crystal --run
require "../../spec_helper"

struct Number
  def int32
    NumberLiteral.new to_s, :i32
  end

  def int64
    NumberLiteral.new to_s, :i64
  end

  def float32
    NumberLiteral.new to_f32.to_s, :f32
  end

  def float64
    NumberLiteral.new to_f64.to_s, :f64
  end
end

struct Bool
  def bool
    BoolLiteral.new self
  end
end

class Array
  def array
    ArrayLiteral.new self
  end

  def array_of(type)
    ArrayLiteral.new self, type
  end

  def path
    Path.new self
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

  def path(global = false)
    Path.new [self], global
  end

  def instance_var
    InstanceVar.new self
  end

  def class_var
    ClassVar.new self
  end

  def string
    StringLiteral.new self
  end

  def float32
    NumberLiteral.new self, :f32
  end

  def float64
    NumberLiteral.new self, :f64
  end

  def symbol
    SymbolLiteral.new self
  end

  def static_array_of(size)
    Generic.new(Path.new(["StaticArray"], true), [Path.new([self]), NumberLiteral.new(size, :i32)])
  end

  def macro_literal
    MacroLiteral.new(self)
  end
end

class Crystal::ASTNode
  def pointer_of
    Generic.new(Path.new(["Pointer"], true), [self] of ASTNode)
  end
end

def it_parses(string, expected_node)
  it "parses #{string}" do
    node = Parser.parse(string)
    node.should eq(Expressions.from expected_node)
  end
end

describe "Parser" do
  it_parses "nil", NilLiteral.new

  it_parses "true", true.bool
  it_parses "false", false.bool

  it_parses "1", 1.int32
  it_parses "+1", 1.int32
  it_parses "-1", -1.int32

  it_parses "1_i64", 1.int64
  it_parses "+1_i64", 1.int64
  it_parses "-1_i64", -1.int64

  it_parses "1.0", 1.0.float64
  it_parses "+1.0", 1.0.float64
  it_parses "-1.0", -1.0.float64

  it_parses "1.0_f32", "1.0".float32
  it_parses "+1.0_f32", "+1.0".float32
  it_parses "-1.0_f32", "-1.0".float32

  it_parses "2.3_f32", 2.3.float32

  it_parses "'a'", CharLiteral.new('a')

  it_parses %("foo"), "foo".string
  it_parses %(""), "".string

  it_parses ":foo", "foo".symbol

  it_parses "[1, 2]", ([1.int32, 2.int32] of ASTNode).array
  it_parses "[\n1, 2]", ([1.int32, 2.int32] of ASTNode).array
  it_parses "[1,\n 2,]", ([1.int32, 2.int32] of ASTNode).array

  it_parses "1 + 2", Call.new(1.int32, "+", [2.int32] of ASTNode)
  it_parses "1 +\n2", Call.new(1.int32, "+", [2.int32] of ASTNode)
  it_parses "1 +2", Call.new(1.int32, "+", [2.int32] of ASTNode)
  it_parses "1 -2", Call.new(1.int32, "-", [2.int32] of ASTNode)
  it_parses "1 +2.0", Call.new(1.int32, "+", [2.float64] of ASTNode)
  it_parses "1 -2.0", Call.new(1.int32, "-", [2.float64] of ASTNode)
  it_parses "1 +2_i64", Call.new(1.int32, "+", [2.int64] of ASTNode)
  it_parses "1 -2_i64", Call.new(1.int32, "-", [2.int64] of ASTNode)
  it_parses "1\n+2", [1.int32, 2.int32] of ASTNode
  it_parses "1;+2", [1.int32, 2.int32] of ASTNode
  it_parses "1 - 2", Call.new(1.int32, "-", [2.int32] of ASTNode)
  it_parses "1 -\n2", Call.new(1.int32, "-", [2.int32] of ASTNode)
  it_parses "1\n-2", [1.int32, -2.int32] of ASTNode
  it_parses "1;-2", [1.int32, -2.int32] of ASTNode
  it_parses "1 * 2", Call.new(1.int32, "*", [2.int32] of ASTNode)
  it_parses "1 * -2", Call.new(1.int32, "*", [-2.int32] of ASTNode)
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int32, "*", [3.int32] of ASTNode), "+", [Call.new(4.int32, "*", [5.int32] of ASTNode)] of ASTNode)
  it_parses "1 / 2", Call.new(1.int32, "/", [2.int32] of ASTNode)
  it_parses "1 / -2", Call.new(1.int32, "/", [-2.int32] of ASTNode)
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int32, "/", [3.int32] of ASTNode), "+", [Call.new(4.int32, "/", [5.int32] of ASTNode)] of ASTNode)
  it_parses "2 * (3 + 4)", Call.new(2.int32, "*", [Call.new(3.int32, "+", [4.int32] of ASTNode)] of ASTNode)
  it_parses "1/2", Call.new(1.int32, "/", [2.int32] of ASTNode)
  it_parses "1 + /foo/", Call.new(1.int32, "+", [RegexLiteral.new("foo")] of ASTNode)
  it_parses "a = 1; a /b", [Assign.new("a".var, 1.int32), Call.new("a".var, "/", ["b".call] of ASTNode)]
  it_parses "a = 1; a/b", [Assign.new("a".var, 1.int32), Call.new("a".var, "/", ["b".call] of ASTNode)]
  it_parses "a = 1; (a)/b", [Assign.new("a".var, 1.int32), Call.new("a".var, "/", ["b".call] of ASTNode)]

  it_parses "!1", Call.new(1.int32, "!")
  it_parses "- 1", Call.new(1.int32, "-")
  it_parses "+ 1", Call.new(1.int32, "+")
  it_parses "~ 1", Call.new(1.int32, "~")
  it_parses "1 && 2", And.new(1.int32, 2.int32)
  it_parses "1 || 2", Or.new(1.int32, 2.int32)

  it_parses "1 <=> 2", Call.new(1.int32, "<=>", [2.int32] of ASTNode)

  it_parses "a = 1", Assign.new("a".var, 1.int32)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int32))

  it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var] of ASTNode, [1.int32] of ASTNode)
  it_parses "a[0], a[1] = 1, 2", MultiAssign.new([Call.new("a".call, "[]", [0.int32] of ASTNode), Call.new("a".call, "[]", [1.int32] of ASTNode)] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "a.foo, a.bar = 1, 2", MultiAssign.new([Call.new("a".call, "foo"), Call.new("a".call, "bar")] of ASTNode, [1.int32, 2.int32] of ASTNode)

  it_parses "def foo\n1\nend", Def.new("foo", [] of Arg, [1.int32] of ASTNode)
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".arg], [1.int32] of ASTNode)
  it_parses "def foo ; 1 ; end", Def.new("foo", [] of Arg, [1.int32] of ASTNode)
  it_parses "def foo; end", Def.new("foo", [] of Arg, nil)
  it_parses "def foo(var); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar\n); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(var1, var2); end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var; end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var\n end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var1, var2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var1,\nvar2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo; 1; 2; end", Def.new("foo", [] of Arg, [1.int32, 2.int32] of ASTNode)
  it_parses "def foo=(value); end", Def.new("foo=", ["value".arg], [] of ASTNode)
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".arg], "foo".call([Call.new("n".var, "-", [1.int32] of ASTNode)] of ASTNode))
  it_parses "def type(type); end", Def.new("type", ["type".arg], nil)

  it_parses "def self.foo\n1\nend", Def.new("foo", [] of Arg, 1.int32, "self".var)
  it_parses "def self.foo()\n1\nend", Def.new("foo", [] of Arg, 1.int32, "self".var)
  it_parses "def self.foo=\n1\nend", Def.new("foo=", [] of Arg, 1.int32, "self".var)
  it_parses "def self.foo=()\n1\nend", Def.new("foo=", [] of Arg, 1.int32, "self".var)
  it_parses "def Foo.foo\n1\nend", Def.new("foo", [] of Arg, 1.int32, "Foo".path)
  it_parses "def Foo::Bar.foo\n1\nend", Def.new("foo", [] of Arg, 1.int32, ["Foo", "Bar"].path)

  it_parses "def foo; a; end", Def.new("foo", [] of Arg, "a".call)
  it_parses "def foo(a); a; end", Def.new("foo", ["a".arg], "a".var)
  it_parses "def foo; a = 1; a; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), "a".var] of ASTNode)
  it_parses "def foo; a = 1; a {}; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), Call.new(nil, "a", [] of ASTNode, Block.new)] of ASTNode)
  it_parses "def foo; a = 1; x { a }; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), Call.new(nil, "x", [] of ASTNode, Block.new([] of Var, ["a".var] of ASTNode))] of ASTNode)
  it_parses "def foo; x { |a| a }; end", Def.new("foo", [] of Arg, [Call.new(nil, "x", [] of ASTNode, Block.new(["a".var], ["a".var] of ASTNode))] of ASTNode)

  it_parses "def foo(var = 1); end", Def.new("foo", [Arg.new("var", 1.int32)], nil)
  it_parses "def foo var = 1; end", Def.new("foo", [Arg.new("var", 1.int32)], nil)
  it_parses "def foo(var : Int); end", Def.new("foo", [Arg.new("var", nil, "Int".path)], nil)
  it_parses "def foo var : Int; end", Def.new("foo", [Arg.new("var", nil, "Int".path)], nil)
  it_parses "def foo(var : self); end", Def.new("foo", [Arg.new("var", nil, Self.new)], nil)
  it_parses "def foo var : self; end", Def.new("foo", [Arg.new("var", nil, Self.new)], nil)
  it_parses "def foo(var : self.class); end", Def.new("foo", [Arg.new("var", nil, Metaclass.new(Self.new))], nil)
  it_parses "def foo(var : self*); end", Def.new("foo", [Arg.new("var", nil, Self.new.pointer_of)], nil)
  it_parses "def foo(var : Int | Double); end", Def.new("foo", [Arg.new("var", nil, Union.new(["Int".path, "Double".path] of ASTNode))], nil)
  it_parses "def foo(var : Int?); end", Def.new("foo", [Arg.new("var", nil, Union.new(["Int".path, "Nil".path(true)] of ASTNode))], nil)
  it_parses "def foo(var : Int*); end", Def.new("foo", [Arg.new("var", nil, "Int".path.pointer_of)], nil)
  it_parses "def foo(var : Int**); end", Def.new("foo", [Arg.new("var", nil, "Int".path.pointer_of.pointer_of)], nil)
  it_parses "def foo(var : Int -> Double); end", Def.new("foo", [Arg.new("var", nil, Fun.new(["Int".path] of ASTNode, "Double".path))], nil)
  it_parses "def foo(var : Int, Float -> Double); end", Def.new("foo", [Arg.new("var", nil, Fun.new(["Int".path, "Float".path] of ASTNode, "Double".path))], nil)
  it_parses "def foo(var : (Int, Float -> Double)); end", Def.new("foo", [Arg.new("var", nil, Fun.new(["Int".path, "Float".path] of ASTNode, "Double".path))], nil)
  it_parses "def foo(var : (Int, Float) -> Double); end", Def.new("foo", [Arg.new("var", nil, Fun.new(["Int".path, "Float".path] of ASTNode, "Double".path))], nil)
  it_parses "def foo(var : Char[256]); end", Def.new("foo", [Arg.new("var", nil, "Char".static_array_of(256))], nil)
  it_parses "def foo(var : Foo+); end", Def.new("foo", [Arg.new("var", nil, Hierarchy.new("Foo".path))], nil)
  it_parses "def foo(var = 1 : Int32); end", Def.new("foo", [Arg.new("var", 1.int32, "Int32".path)], nil)
  it_parses "def foo; yield; end", Def.new("foo", [] of Arg, [Yield.new] of ASTNode, nil, nil, nil, 0)
  it_parses "def foo; yield 1; end", Def.new("foo", [] of Arg, [Yield.new([1.int32] of ASTNode)] of ASTNode, nil, nil, nil, 1)
  it_parses "def foo; yield 1; yield; end", Def.new("foo", [] of Arg, [Yield.new([1.int32] of ASTNode), Yield.new] of ASTNode, nil, nil, nil, 1)
  it_parses "def foo(a, b = a); end", Def.new("foo", [Arg.new("a"), Arg.new("b", "a".var)], nil)
  it_parses "def foo(&block); end", Def.new("foo", [] of Arg, nil, nil, BlockArg.new("block"), nil, 0)
  it_parses "def foo(a, &block); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block"), nil, 0)
  it_parses "def foo a, &block\nend", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block"), nil, 0)
  it_parses "def foo(a, &block : Int -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", Fun.new(["Int".path] of ASTNode, "Double".path)), nil, 1)
  it_parses "def foo(a, &block : Int, Float -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", Fun.new(["Int".path, "Float".path] of ASTNode, "Double".path)), nil, 2)
  it_parses "def foo(a, &block : -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", Fun.new(nil, "Double".path)), nil, 0)
  it_parses "def foo(a, &block : Int -> ); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", Fun.new(["Int".path] of ASTNode)), nil, 1)
  it_parses "def foo(a, &block : self -> self); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", Fun.new([Self.new] of ASTNode, Self.new)), nil, 1)
  it_parses "def foo; with a yield; end", Def.new("foo", [] of Arg, [Yield.new([] of ASTNode, "a".call)] of ASTNode, nil, nil, nil, 1)
  it_parses "def foo; with a yield 1; end", Def.new("foo", [] of Arg, [Yield.new([1.int32] of ASTNode, "a".call)] of ASTNode, nil, nil, nil, 1)
  it_parses "def foo; a = 1; with a yield a; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), Yield.new(["a".var] of ASTNode, "a".var)] of ASTNode, nil, nil, nil, 1)
  it_parses "def foo(@var); end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var)] of ASTNode)
  it_parses "def foo(@var); 1; end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(@var = 1); 1; end", Def.new("foo", [Arg.new("var", 1.int32)], [Assign.new("@var".instance_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(@@var); end", Def.new("foo", [Arg.new("var")], [Assign.new("@@var".class_var, "var".var)] of ASTNode)
  it_parses "def foo(@@var); 1; end", Def.new("foo", [Arg.new("var")], [Assign.new("@@var".class_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(@@var = 1); 1; end", Def.new("foo", [Arg.new("var", 1.int32)], [Assign.new("@@var".class_var, "var".var), 1.int32] of ASTNode)

  it_parses "def foo(&@block); end", Def.new("foo", [] of Arg, Assign.new("@block".instance_var, "block".var), nil, BlockArg.new("block"), nil, 0)
  it_parses "def foo @var, &block; end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var)] of ASTNode, nil, BlockArg.new("block"), nil, 0)

  it_parses "abstract def foo", Def.new("foo", [] of Arg, Nop.new, nil, nil, nil, nil, true)
  it_parses "abstract def foo; 1", [Def.new("foo", [] of Arg, Nop.new, nil, nil, nil, nil, true), 1.int32]
  it_parses "abstract def foo\n1", [Def.new("foo", [] of Arg, Nop.new, nil, nil, nil, nil, true), 1.int32]
  it_parses "abstract def foo(x)", Def.new("foo", ["x".arg], Nop.new, nil, nil, nil, nil, true)

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1\n", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1;", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1, 2", "foo".call([1.int32, 2.int32] of ASTNode)
  it_parses "foo (1 + 2), 3", "foo".call([Call.new(1.int32, "+", [2.int32] of ASTNode), 3.int32] of ASTNode)
  it_parses "foo(1 + 2)", "foo".call([Call.new(1.int32, "+", [2.int32] of ASTNode)] of ASTNode)
  it_parses "foo -1.0, -2.0", "foo".call([-1.float64, -2.float64] of ASTNode)
  it_parses "foo(\n1)", "foo".call([1.int32] of ASTNode)
  it_parses "::foo", Call.new(nil, "foo", [] of ASTNode, nil, nil, true)

  it_parses "foo + 1", Call.new("foo".call, "+", [1.int32] of ASTNode)
  it_parses "foo +1", Call.new(nil, "foo", [1.int32] of ASTNode)
  it_parses "foo +1.0", Call.new(nil, "foo", [1.float64] of ASTNode)
  it_parses "foo +1_i64", Call.new(nil, "foo", [1.int64] of ASTNode)
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, "+", [1.int32] of ASTNode)]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, "-", [1.int32] of ASTNode)]

  it_parses "foo(&block)", Call.new(nil, "foo", [] of ASTNode, nil, "block".call)
  it_parses "foo &block", Call.new(nil, "foo", [] of ASTNode, nil, "block".call)
  it_parses "a.foo &block", Call.new("a".call, "foo", [] of ASTNode, nil, "block".call)
  it_parses "a.foo(&block)", Call.new("a".call, "foo", [] of ASTNode, nil, "block".call)

  it_parses "foo(&.block)", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Var.new("#arg0"), "block")))
  it_parses "foo &.block", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Var.new("#arg0"), "block")))
  it_parses "foo &.block(1)", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Var.new("#arg0"), "block", [1.int32] of ASTNode)))
  it_parses "foo &.+(2)", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Var.new("#arg0"), "+", [2.int32] of ASTNode)))
  it_parses "foo &.bar.baz", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Call.new(Var.new("#arg0"), "bar"), "baz")))
  it_parses "foo(&.bar.baz)", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Call.new(Var.new("#arg0"), "bar"), "baz")))
  it_parses "foo &.block[0]", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Call.new(Var.new("#arg0"), "block"), "[]", [0.int32] of ASTNode)))
  it_parses "foo &.[0]", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], Call.new(Var.new("#arg0"), "[]", [0.int32] of ASTNode)))
  it_parses "foo(&.is_a?(T))", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], IsA.new(Var.new("#arg0"), "T".path)))
  it_parses "foo(&.responds_to?(:foo))", Call.new(nil, "foo", [] of ASTNode, Block.new([Var.new("#arg0")], RespondsTo.new(Var.new("#arg0"), "foo".symbol)))

  it_parses "x = 1; foo x do\nend", [Assign.new("x".var, 1.int32), Call.new(nil, "foo", ["x".var] of ASTNode, Block.new)]
  it_parses "x = 1; foo x { }", [Assign.new("x".var, 1.int32), Call.new(nil, "foo", [Call.new(nil, "x", [] of ASTNode, Block.new)] of ASTNode)]
  it_parses "x = 1; foo x {\n}", [Assign.new("x".var, 1.int32), Call.new(nil, "foo", [Call.new(nil, "x", [] of ASTNode, Block.new)] of ASTNode)]

  it_parses "foo !false", Call.new(nil, "foo", [Call.new(false.bool, "!")] of ASTNode)
  it_parses "!a && b", And.new(Call.new("a".call, "!"), "b".call)

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".path, "new")] of ASTNode)
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".path, "new")] of ASTNode)
  it_parses "f.x = - 1", Call.new("f".call, "x=", [Call.new(1.int32, "-")] of ASTNode)

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "f.x #{op}= 2", Call.new("f".call, "x=", [Call.new(Call.new("f".call, "x"), op, [2.int32] of ASTNode)] of ASTNode)
  end

  ["/", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "!", "~", "%", "&", "|", "^", "**", "==="].each do |op|
    it_parses "def #{op}; end;", Def.new(op, [] of Arg, nil)
  end

  it_parses "def %(); end;", Def.new("%", [] of Arg, nil)
  it_parses "def /(); end;", Def.new("/", [] of Arg, nil)

  ["<<", "<", "<=", "==", ">>", ">", ">=", "+", "-", "*", "/", "%", "|", "&", "^", "**", "==="].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int32, op, [2.int32] of ASTNode)
    it_parses "n #{op} 2", Call.new("n".call, op, [2.int32] of ASTNode)
  end

  ["bar", "+", "-", "*", "/", "<", "<=", "==", ">", ">=", "%", "|", "&", "^", "**", "==="].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, [1.int32, 2.int32] of ASTNode)
  end

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "a = 1; a #{op}= 1", [Assign.new("a".var, 1.int32), Assign.new("a".var, Call.new("a".var, op, [1.int32] of ASTNode))] of ASTNode
  end

  it_parses "a = 1; a &&= 1", [Assign.new("a".var, 1.int32), And.new("a".var, Assign.new("a".var, 1.int32))]
  it_parses "a = 1; a ||= 1", [Assign.new("a".var, 1.int32), Or.new("a".var, Assign.new("a".var, 1.int32))]

  it_parses "a = 1; a[2] &&= 3", [Assign.new("a".var, 1.int32), And.new(Call.new("a".var, "[]?", [2.int32] of ASTNode), Call.new("a".var, "[]=", [2.int32, 3.int32] of ASTNode))]
  it_parses "a = 1; a[2] ||= 3", [Assign.new("a".var, 1.int32), Or.new(Call.new("a".var, "[]?", [2.int32] of ASTNode), Call.new("a".var, "[]=", [2.int32, 3.int32] of ASTNode))]

  it_parses "if foo; 1; end", If.new("foo".call, 1.int32)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int32)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int32, If.new("bar".call, 2.int32, 3.int32))

  it_parses "ifdef foo; 1; end", IfDef.new("foo".var, 1.int32)
  it_parses "ifdef foo; 1; else; 2; end", IfDef.new("foo".var, 1.int32, 2.int32)
  it_parses "ifdef foo; 1; elsif bar; 2; else 3; end", IfDef.new("foo".var, 1.int32, IfDef.new("bar".var, 2.int32, 3.int32))
  it_parses "ifdef (!a || b) && c; 1; end", IfDef.new(And.new(Or.new(Not.new("a".var), "b".var), "c".var), 1.int32)
  it_parses "ifdef !(a || b) && c; 1; end", IfDef.new(And.new(Not.new(Or.new("a".var, "b".var)), "c".var), 1.int32)

  it_parses "include Foo", Include.new("Foo".path)
  it_parses "include Foo\nif true; end", [Include.new("Foo".path), If.new(true.bool)]
  it_parses "extend Foo", Extend.new("Foo".path)
  it_parses "extend Foo\nif true; end", [Extend.new("Foo".path), If.new(true.bool)]
  it_parses "extend self", Extend.new(Self.new)

  it_parses "unless foo; 1; end", Unless.new("foo".call, 1.int32)
  it_parses "unless foo; 1; else; 2; end", Unless.new("foo".call, 1.int32, 2.int32)

  it_parses "class Foo; end", ClassDef.new("Foo".path)
  it_parses "class Foo\nend", ClassDef.new("Foo".path)
  it_parses "class Foo\ndef foo; end; end", ClassDef.new("Foo".path, [Def.new("foo", [] of Arg, nil)] of ASTNode)
  it_parses "class Foo < Bar; end", ClassDef.new("Foo".path, nil, "Bar".path)
  it_parses "class Foo(T); end", ClassDef.new("Foo".path, nil, nil, ["T"])
  it_parses "abstract class Foo; end", ClassDef.new("Foo".path, nil, nil, nil, true)

  it_parses "struct Foo; end", ClassDef.new("Foo".path, nil, nil, nil, false, true)

  it_parses "Foo(T)", Generic.new("Foo".path, ["T".path] of ASTNode)
  it_parses "Foo(T | U)", Generic.new("Foo".path, [Union.new(["T".path, "U".path] of ASTNode)] of ASTNode)
  it_parses "Foo(Bar(T | U))", Generic.new("Foo".path, [Generic.new("Bar".path, [Union.new(["T".path, "U".path] of ASTNode)] of ASTNode)] of ASTNode)
  it_parses "Foo(T?)", Generic.new("Foo".path, [Union.new(["T".path, Path.new(["Nil"], true)] of ASTNode)] of ASTNode)
  it_parses "Foo(1)", Generic.new("Foo".path, [NumberLiteral.new("1", :i32)] of ASTNode)
  it_parses "Foo(T, 1)", Generic.new("Foo".path, ["T".path, NumberLiteral.new("1", :i32)] of ASTNode)
  it_parses "Foo(T, U, 1)", Generic.new("Foo".path, ["T".path, "U".path, NumberLiteral.new("1", :i32)] of ASTNode)
  it_parses "Foo(T, 1, U)", Generic.new("Foo".path, ["T".path, NumberLiteral.new("1", :i32), "U".path] of ASTNode)
  it_parses "Foo(typeof(1))", Generic.new("Foo".path, [TypeOf.new([1.int32] of ASTNode)] of ASTNode)
  it_parses "Foo({X, Y})", Generic.new("Foo".path, [Generic.new(Path.new(["Tuple"], true), ["X".path, "Y".path] of ASTNode)] of ASTNode)
  it_parses "Foo({X, Y})", Generic.new("Foo".path, [Generic.new(Path.new(["Tuple"], true), ["X".path, "Y".path] of ASTNode)] of ASTNode)
  it_parses "Foo({->})", Generic.new("Foo".path, [Generic.new(Path.new(["Tuple"], true), [Fun.new] of ASTNode)] of ASTNode)
  it_parses "Foo({String, ->})", Generic.new("Foo".path, [Generic.new(Path.new(["Tuple"], true), ["String".path, Fun.new] of ASTNode)] of ASTNode)
  it_parses "Foo({String, ->, ->})", Generic.new("Foo".path, [Generic.new(Path.new(["Tuple"], true), ["String".path, Fun.new, Fun.new] of ASTNode)] of ASTNode)
  it_parses "[] of {String, ->}", ArrayLiteral.new([] of ASTNode, Generic.new(Path.new(["Tuple"], true), ["String".path, Fun.new] of ASTNode))
  it_parses "x([] of Foo, Bar.new)", Call.new(nil, "x", [ArrayLiteral.new([] of ASTNode, "Foo".path), Call.new("Bar".path, "new")] of ASTNode)

  it_parses "module Foo; end", ModuleDef.new("Foo".path)
  it_parses "module Foo\ndef foo; end; end", ModuleDef.new("Foo".path, [Def.new("foo", [] of Arg, nil)] of ASTNode)
  it_parses "module Foo(T); end", ModuleDef.new("Foo".path, nil, ["T"])

  it_parses "while true; end;", While.new(true.bool)
  it_parses "while true; 1; end;", While.new(true.bool, 1.int32)

  it_parses "until true; end;", Until.new(true.bool)
  it_parses "until true; 1; end;", Until.new(true.bool, 1.int32)

  it_parses "foo do; 1; end", Call.new(nil, "foo", [] of ASTNode, Block.new([] of Var, 1.int32))
  it_parses "foo do |a|; 1; end", Call.new(nil, "foo", [] of ASTNode, Block.new(["a".var], 1.int32))

  it_parses "foo { 1 }", Call.new(nil, "foo", [] of ASTNode, Block.new([] of Var, 1.int32))
  it_parses "foo { |a| 1 }", Call.new(nil, "foo", [] of ASTNode, Block.new(["a".var], 1.int32))
  it_parses "foo { |a, b| 1 }", Call.new(nil, "foo", [] of ASTNode, Block.new(["a".var, "b".var], 1.int32))
  it_parses "1.foo do; 1; end", Call.new(1.int32, "foo", [] of ASTNode, Block.new([] of Var, 1.int32))

  it_parses "1 ? 2 : 3", If.new(1.int32, 2.int32, 3.int32)
  it_parses "1 ? a : b", If.new(1.int32, "a".call, "b".call)

  it_parses "1 if 3", If.new(3.int32, 1.int32)
  it_parses "1 unless 3", Unless.new(3.int32, 1.int32)
  it_parses "1 while 3", While.new(3.int32, 1.int32, true)
  it_parses "1 until 3", Until.new(3.int32, 1.int32, true)
  it_parses "a = 1; a += 10 if a += 20", [Assign.new("a".var, 1.int32), If.new(Assign.new("a".var, Call.new("a".var, "+", [20.int32] of ASTNode)), Assign.new("a".var, Call.new("a".var, "+", [10.int32] of ASTNode)))]
  it_parses "puts a if true", If.new(true.bool, Call.new(nil, "puts", ["a".call] of ASTNode))
  it_parses "puts a unless true", Unless.new(true.bool, Call.new(nil, "puts", ["a".call] of ASTNode))
  it_parses "puts a while true", While.new(true.bool, Call.new(nil, "puts", ["a".call] of ASTNode), true)

  it_parses "return", Return.new
  it_parses "return;", Return.new
  it_parses "return 1", Return.new([1.int32] of ASTNode)
  it_parses "return 1 if true", If.new(true.bool, Return.new([1.int32] of ASTNode))
  it_parses "return if true", If.new(true.bool, Return.new)

  it_parses "break", Break.new
  it_parses "break;", Break.new
  it_parses "break 1", Break.new([1.int32] of ASTNode)
  it_parses "break 1 if true", If.new(true.bool, Break.new([1.int32] of ASTNode))
  it_parses "break if true", If.new(true.bool, Break.new)

  it_parses "next", Next.new
  it_parses "next;", Next.new
  it_parses "next 1", Next.new([1.int32] of ASTNode)
  it_parses "next 1 if true", If.new(true.bool, Next.new([1.int32] of ASTNode))
  it_parses "next if true", If.new(true.bool, Next.new)

  it_parses "yield", Yield.new
  it_parses "yield;", Yield.new
  it_parses "yield 1", Yield.new([1.int32] of ASTNode)
  it_parses "yield 1 if true", If.new(true.bool, Yield.new([1.int32] of ASTNode))
  it_parses "yield if true", If.new(true.bool, Yield.new)

  it_parses "Int", "Int".path

  it_parses "Int[]", Call.new("Int".path, "[]")
  it_parses "def []; end", Def.new("[]", [] of Arg, nil)
  it_parses "def []?; end", Def.new("[]?", [] of Arg, nil)
  it_parses "def []=(value); end", Def.new("[]=", ["value".arg], nil)
  it_parses "def self.[]; end", Def.new("[]", [] of Arg, nil, "self".var)

  it_parses "Int[8]", Call.new("Int".path, "[]", [8.int32] of ASTNode)
  it_parses "Int[8, 4]", Call.new("Int".path, "[]", [8.int32, 4.int32] of ASTNode)
  it_parses "Int[8, 4,]", Call.new("Int".path, "[]", [8.int32, 4.int32] of ASTNode)
  it_parses "Int[8]?", Call.new("Int".path, "[]?", [8.int32] of ASTNode)
  it_parses "x[0] ? 1 : 0", If.new(Call.new("x".call, "[]", [0.int32] of ASTNode), 1.int32, 0.int32)

  it_parses "def [](x); end", Def.new("[]", ["x".arg], nil)

  it_parses "foo[0] = 1", Call.new("foo".call, "[]=", [0.int32, 1.int32] of ASTNode)
  it_parses "foo[0] = 1 if 2", If.new(2.int32, Call.new("foo".call, "[]=", [0.int32, 1.int32] of ASTNode))

  it_parses "begin; 1; 2; 3; end;", Expressions.new([1.int32, 2.int32, 3.int32] of ASTNode)

  it_parses "self", "self".var

  it_parses "@foo", "@foo".instance_var
  it_parses "@foo = 1", Assign.new("@foo".instance_var, 1.int32)
  it_parses "-@foo", Call.new("@foo".instance_var, "-")

  it_parses "var.@foo", ReadInstanceVar.new("var".call, "@foo")
  it_parses "var.@foo.@bar", ReadInstanceVar.new(ReadInstanceVar.new("var".call, "@foo"), "@bar")

  it_parses "@@foo", "@@foo".class_var
  it_parses "@@foo = 1", Assign.new("@@foo".class_var, 1.int32)
  it_parses "-@@foo", Call.new("@@foo".class_var, "-")

  it_parses "call @foo.bar", Call.new(nil, "call", [Call.new("@foo".instance_var, "bar")] of ASTNode)
  it_parses "call \"foo\"", Call.new(nil, "call", ["foo".string] of ASTNode)

  it_parses "def foo; end; if false; 1; else; 2; end", [Def.new("foo", [] of Arg), If.new(false.bool, 1.int32, 2.int32)]

  it_parses "A.new(\"x\", B.new(\"y\"))", Call.new("A".path, "new", ["x".string, Call.new("B".path, "new", ["y".string] of ASTNode)] of ASTNode)

  it_parses "foo [1]", Call.new(nil, "foo", [([1.int32] of ASTNode).array] of ASTNode)
  it_parses "foo.bar [1]", Call.new("foo".call, "bar", [([1.int32] of ASTNode).array] of ASTNode)

  it_parses "class Foo; end\nwhile true; end", [ClassDef.new("Foo".path), While.new(true.bool)]
  it_parses "while true; end\nif true; end", [While.new(true.bool), If.new(true.bool)]
  it_parses "(1)\nif true; end", [1.int32, If.new(true.bool)]
  it_parses "begin\n1\nend\nif true; end", [1.int32, If.new(true.bool)]

  it_parses "Foo::Bar", ["Foo", "Bar"].path

  it_parses "lib C\nend", LibDef.new("C")
  it_parses "lib C(\"libc\")\nend", LibDef.new("C", "libc")
  it_parses "lib C\nfun getchar\nend", LibDef.new("C", nil, [FunDef.new("getchar")] of ASTNode)
  it_parses "lib C\nfun getchar(...)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [] of Arg, nil, true)] of ASTNode)
  it_parses "lib C\nfun getchar : Int\nend", LibDef.new("C", nil, [FunDef.new("getchar", [] of Arg, "Int".path)] of ASTNode)
  it_parses "lib C\nfun getchar : (->)?\nend", LibDef.new("C", nil, [FunDef.new("getchar", [] of Arg, Union.new([Fun.new, "Nil".path(true)] of ASTNode))] of ASTNode)
  it_parses "lib C\nfun getchar(Int, Float)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [Arg.new("", nil, "Int".path), Arg.new("", nil, "Float".path)])] of ASTNode)
  it_parses "lib C\nfun getchar(a : Int, b : Float)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [Arg.new("a", nil, "Int".path), Arg.new("b", nil, "Float".path)])] of ASTNode)
  it_parses "lib C\nfun getchar(a : Int)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [Arg.new("a", nil, "Int".path)])] of ASTNode)
  it_parses "lib C\nfun getchar(a : Int, b : Float) : Int\nend", LibDef.new("C", nil, [FunDef.new("getchar", [Arg.new("a", nil, "Int".path), Arg.new("b", nil, "Float".path)], "Int".path)] of ASTNode)
  it_parses "lib C; fun getchar(a : Int, b : Float) : Int; end", LibDef.new("C", nil, [FunDef.new("getchar", [Arg.new("a", nil, "Int".path), Arg.new("b", nil, "Float".path)], "Int".path)] of ASTNode)
  it_parses "lib C; fun foo(a : Int*); end", LibDef.new("C", nil, [FunDef.new("foo", [Arg.new("a", nil, "Int".path.pointer_of)])] of ASTNode)
  it_parses "lib C; fun foo(a : Int**); end", LibDef.new("C", nil, [FunDef.new("foo", [Arg.new("a", nil, "Int".path.pointer_of.pointer_of)])] of ASTNode)
  it_parses "lib C; fun foo : Int*; end", LibDef.new("C", nil, [FunDef.new("foo", [] of Arg, "Int".path.pointer_of)] of ASTNode)
  it_parses "lib C; fun foo : Int**; end", LibDef.new("C", nil, [FunDef.new("foo", [] of Arg, "Int".path.pointer_of.pointer_of)] of ASTNode)
  it_parses "lib C; type A : B; end", LibDef.new("C", nil, [TypeDef.new("A", "B".path)] of ASTNode)
  it_parses "lib C; type A : B*; end", LibDef.new("C", nil, [TypeDef.new("A", "B".path.pointer_of)] of ASTNode)
  it_parses "lib C; type A : B**; end", LibDef.new("C", nil, [TypeDef.new("A", "B".path.pointer_of.pointer_of)] of ASTNode)
  it_parses "lib C; type A : B.class; end", LibDef.new("C", nil, [TypeDef.new("A", Metaclass.new("B".path))] of ASTNode)
  it_parses "lib C; struct Foo; end end", LibDef.new("C", nil, [StructDef.new("Foo")] of ASTNode)
  it_parses "lib C; struct Foo; x : Int; y : Float; end end", LibDef.new("C", nil, [StructDef.new("Foo", [Arg.new("x", nil, "Int".path), Arg.new("y", nil, "Float".path)])] of ASTNode)
  it_parses "lib C; struct Foo; x : Int*; end end", LibDef.new("C", nil, [StructDef.new("Foo", [Arg.new("x", nil, "Int".path.pointer_of)])] of ASTNode)
  it_parses "lib C; struct Foo; x : Int**; end end", LibDef.new("C", nil, [StructDef.new("Foo", [Arg.new("x", nil, "Int".path.pointer_of.pointer_of)])] of ASTNode)
  it_parses "lib C; struct Foo; x, y, z : Int; end end", LibDef.new("C", nil, [StructDef.new("Foo", [Arg.new("x", nil, "Int".path), Arg.new("y", nil, "Int".path), Arg.new("z", nil, "Int".path)])] of ASTNode)
  it_parses "lib C; union Foo; end end", LibDef.new("C", nil, [UnionDef.new("Foo")] of ASTNode)
  it_parses "lib C; enum Foo; A\nB, C\nD = 1; end end", LibDef.new("C", nil, [EnumDef.new("Foo", [Arg.new("A"), Arg.new("B"), Arg.new("C"), Arg.new("D", 1.int32)])] of ASTNode)
  it_parses "lib C; enum Foo; A = 1, B; end end", LibDef.new("C", nil, [EnumDef.new("Foo", [Arg.new("A", 1.int32), Arg.new("B")])] of ASTNode)
  it_parses "lib C; enum Foo < UInt16; end end", LibDef.new("C", nil, [EnumDef.new("Foo", [] of Arg, "UInt16".path)] of ASTNode)
  it_parses "lib C; Foo = 1; end", LibDef.new("C", nil, [Assign.new("Foo".path, 1.int32)] of ASTNode)
  it_parses "lib C\nfun getch = GetChar\nend", LibDef.new("C", nil, [FunDef.new("getch", [] of Arg, nil, false, nil, "GetChar")] of ASTNode)
  it_parses %(lib C\nfun getch = "get.char"\nend), LibDef.new("C", nil, [FunDef.new("getch", [] of Arg, nil, false, nil, "get.char")] of ASTNode)
  it_parses %(lib C\nfun getch = "get.char"(x : Int32)\nend), LibDef.new("C", nil, [FunDef.new("getch", [Arg.new("x", nil, "Int32".path)], nil, false, nil, "get.char")] of ASTNode)
  it_parses "lib C\n$errno : Int32\n$errno2 : Int32\nend", LibDef.new("C", nil, [ExternalVar.new("errno", "Int32".path), ExternalVar.new("errno2", "Int32".path)] of ASTNode)
  it_parses "lib C\n$errno : B, C -> D\nend", LibDef.new("C", nil, [ExternalVar.new("errno", Fun.new(["B".path, "C".path] of ASTNode, "D".path))] of ASTNode)
  it_parses "lib C\n$errno = Foo : Int32\nend", LibDef.new("C", nil, [ExternalVar.new("errno", "Int32".path, "Foo")] of ASTNode)
  it_parses "lib C\nalias Foo = Bar\nend", LibDef.new("C", nil, [Alias.new("Foo", "Bar".path)] of ASTNode)

  it_parses "lib C\nifdef foo\ntype A : B\nend\nend", LibDef.new("C", nil, [IfDef.new("foo".var, TypeDef.new("A", "B".path))] of ASTNode)

  it_parses "fun foo(x : Int32) : Int64\nx\nend", FunDef.new("foo", [Arg.new("x", nil, "Int32".path)], "Int64".path, false, "x".var)

  it_parses "1 .. 2", RangeLiteral.new(1.int32, 2.int32, false)
  it_parses "1 ... 2", RangeLiteral.new(1.int32, 2.int32, true)

  it_parses "A = 1", Assign.new("A".path, 1.int32)

  it_parses "puts %w(one two)", Call.new(nil, "puts", [(["one".string, "two".string] of ASTNode).array] of ASTNode)
  it_parses "puts %i(one two)", Call.new(nil, "puts", [(["one".symbol, "two".symbol] of ASTNode).array] of ASTNode)

  it_parses "[] of Int", ([] of ASTNode).array_of("Int".path)
  it_parses "[1, 2] of Int", ([1.int32, 2.int32] of ASTNode).array_of("Int".path)

  it_parses "::A::B", Path.new(["A", "B"], true)

  it_parses "$foo", Global.new("$foo")

  it_parses "macro foo;end", Macro.new("foo", [] of Arg, Expressions.from([] of ASTNode))
  it_parses %(macro foo; 1 + 2; end), Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses %(macro foo x; 1 + 2; end), Macro.new("foo", ([Arg.new("x")]), Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses %(macro foo x\n 1 + 2; end), Macro.new("foo", ([Arg.new("x")]), Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses %(macro foo(x); 1 + 2; end), Macro.new("foo", ([Arg.new("x")]), Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses %(macro foo(x)\n 1 + 2; end), Macro.new("foo", ([Arg.new("x")]), Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses "macro foo; 1 + 2 {{foo}} 3 + 4; end", Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2 ".macro_literal, MacroExpression.new("foo".var), " 3 + 4; ".macro_literal] of ASTNode))
  it_parses "macro foo; 1 + 2 {{ foo }} 3 + 4; end", Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2 ".macro_literal, MacroExpression.new("foo".var), " 3 + 4; ".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% for x in y %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var], "y".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% for x, y in z %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var, "y".var], "z".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% else %}body2{%end%}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal, "body2".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% elsif y %}body2{%end%}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal, MacroIf.new("y".var, "body2".macro_literal)), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% unless x %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, Nop.new, "body".macro_literal), "baz;".macro_literal] of ASTNode))

  it_parses "macro foo;bar{% for x in y %}\\  \n   body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var], "y".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% for x in y %}\\  \n   body{% end %}\\   baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var], "y".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo; 1 + 2 {{foo}}\\ 3 + 4; end", Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2 ".macro_literal, MacroExpression.new("foo".var), "3 + 4; ".macro_literal] of ASTNode))

  it_parses "def foo : String; 1; end", Def.new("foo", [] of Arg, [MacroLiteral.new(" 1; ")] of ASTNode, nil, nil, "String".path)
  it_parses "def foo(x) : String; 1; end", Def.new("foo", ["x".arg], [MacroLiteral.new(" 1; ")] of ASTNode, nil, nil, "String".path)

  it_parses "{% for x in y %}body{% end %}", MacroFor.new(["x".var], "y".var, "body".macro_literal)
  it_parses "{% if x %}body{% end %}", MacroIf.new("x".var, "body".macro_literal)
  it_parses "{{ foo }}", MacroExpression.new("foo".var)

  it_parses "a = 1; pointerof(a)", [Assign.new("a".var, 1.int32), PointerOf.new("a".var)]
  it_parses "pointerof(@a)", PointerOf.new("@a".instance_var)
  it_parses "a = 1; pointerof(a)", [Assign.new("a".var, 1.int32), PointerOf.new("a".var)]
  it_parses "pointerof(@a)", PointerOf.new("@a".instance_var)

  it_parses "sizeof(X)", SizeOf.new("X".path)
  it_parses "instance_sizeof(X)", InstanceSizeOf.new("X".path)

  it_parses "foo.is_a?(Const)", IsA.new("foo".call, "Const".path)
  it_parses "foo.is_a?(Foo | Bar)", IsA.new("foo".call, Union.new(["Foo".path, "Bar".path] of ASTNode))
  it_parses "foo.responds_to?(:foo)", RespondsTo.new("foo".call, "foo".symbol)

  it_parses "/foo/", RegexLiteral.new("foo")
  it_parses "/foo/i", RegexLiteral.new("foo", Regex::IGNORE_CASE)
  it_parses "/foo/m", RegexLiteral.new("foo", Regex::MULTILINE)
  it_parses "/foo/x", RegexLiteral.new("foo", Regex::EXTENDED)
  it_parses "/foo/imximx", RegexLiteral.new("foo", Regex::IGNORE_CASE | Regex::MULTILINE | Regex::EXTENDED)

  it_parses "1 =~ 2", Call.new(1.int32, "=~", [2.int32] of ASTNode)
  it_parses "1.=~(2)", Call.new(1.int32, "=~", [2.int32] of ASTNode)
  it_parses "def =~; end", Def.new("=~", [] of Arg)

  it_parses "foo $a", Call.new(nil, "foo", [Global.new("$a")] of ASTNode)

  it_parses "$1", Call.new(Global.new("$~"), "[]", [1.int32] of ASTNode)
  it_parses "foo $1", Call.new(nil, "foo", [Call.new(Global.new("$~"), "[]", [1.int32] of ASTNode)] of ASTNode)
  it_parses "foo /a/", Call.new(nil, "foo", [RegexLiteral.new("a")] of ASTNode)

  it_parses "foo out x; x", [Call.new(nil, "foo", [(v = Var.new("x"); v.out = true; v)] of ASTNode), Var.new("x")]
  it_parses "foo(out x); x", [Call.new(nil, "foo", [(v = Var.new("x"); v.out = true; v)] of ASTNode), Var.new("x")]

  it_parses "{1 => 2, 3 => 4}", HashLiteral.new([1.int32, 3.int32] of ASTNode, [2.int32, 4.int32] of ASTNode)
  it_parses "{a: 1, b: 2}", HashLiteral.new(["a".symbol, "b".symbol] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "{a: 1, 3 => 4, b: 2}", HashLiteral.new(["a".symbol, 3.int32, "b".symbol] of ASTNode, [1.int32, 4.int32, 2.int32] of ASTNode)
  it_parses "{A: 1, 3 => 4, B: 2}", HashLiteral.new(["A".symbol, 3.int32, "B".symbol] of ASTNode, [1.int32, 4.int32, 2.int32] of ASTNode)

  it_parses "{} of Int => Double", HashLiteral.new([] of ASTNode, [] of ASTNode, "Int".path, "Double".path)

  it_parses "require \"foo\"", Require.new("foo")
  it_parses "require \"foo\"; [1]", [Require.new("foo"), ([1.int32] of ASTNode).array]

  it_parses "case 1; when 1; 2; else; 3; end", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1; when 0, 1; 2; else; 3; end", Case.new(1.int32, [When.new([0.int32, 1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nelse\n3\nend", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nend", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)])

  it_parses "case 1; when 1 then 2; else; 3; end", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nend\nif a\nend", [Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)]), If.new("a".call)]
  it_parses "case\n1\nwhen 1\n2\nend\nif a\nend", [Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)]), If.new("a".call)]

  it_parses "case 1\nwhen .foo\n2\nend", Case.new(1.int32, [When.new([Call.new(ImplicitObj.new, "foo")] of ASTNode, 2.int32)])
  it_parses "case when 1\n2\nend", Case.new(nil, [When.new([1.int32] of ASTNode, 2.int32)])
  it_parses "case \nwhen 1\n2\nend", Case.new(nil, [When.new([1.int32] of ASTNode, 2.int32)])

  it_parses "def foo(x); end; x", [Def.new("foo", ["x".arg]), "x".call]

  it_parses "\"foo\#{bar}baz\"", StringInterpolation.new(["foo".string, "bar".call, "baz".string])

  # When interpolating a string we don't necessarily need interpolation.
  # This is useful for example when interpolating __FILE__ and __DIR__
  it_parses "\"foo\#{\"bar\"}baz\"", "foobarbaz".string

  it_parses "lib Foo\nend\nif true\nend", [LibDef.new("Foo"), If.new(true.bool)]

  it_parses "foo(\n1\n)", Call.new(nil, "foo", [1.int32] of ASTNode)

  it_parses "a = 1\nfoo - a", [Assign.new("a".var, 1.int32), Call.new("foo".call, "-", ["a".var] of ASTNode)]
  it_parses "a = 1\nfoo -a", [Assign.new("a".var, 1.int32), Call.new(nil, "foo", [Call.new("a".var, "-")] of ASTNode)]

  it_parses "a :: Foo", DeclareVar.new("a".var, "Foo".path)
  it_parses "a :: Foo | Int32", DeclareVar.new("a".var, Union.new(["Foo".path, "Int32".path] of ASTNode))
  it_parses "@a :: Foo | Int32", DeclareVar.new("@a".instance_var, Union.new(["Foo".path, "Int32".path] of ASTNode))

  it_parses "()", NilLiteral.new
  it_parses "(1; 2; 3)", [1.int32, 2.int32, 3.int32] of ASTNode

  it_parses "begin; rescue; end", ExceptionHandler.new(Nop.new, [Rescue.new])
  it_parses "begin; 1; rescue; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])
  it_parses "begin; 1; ensure; 2; end", ExceptionHandler.new(1.int32, nil, nil, 2.int32)
  it_parses "begin\n1\nensure\n2\nend", ExceptionHandler.new(1.int32, nil, nil, 2.int32)
  it_parses "begin; 1; rescue Foo; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".path] of ASTNode)])
  it_parses "begin; 1; rescue Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".path, "Bar".path] of ASTNode)])
  it_parses "begin; 1; rescue ex : Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".path, "Bar".path] of ASTNode, "ex")])
  it_parses "begin; 1; rescue ex; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, nil, "ex")])
  it_parses "begin; 1; rescue; 2; else; 3; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)], 3.int32)

  it_parses "def foo(); 1; rescue; 2; end", Def.new("foo", [] of Arg, ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))

  it_parses "1 rescue 2", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])
  it_parses "x = 1 rescue 2", Assign.new("x".var, ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))

  it_parses "1 <= 2 <= 3", Call.new(Call.new(1.int32, "<=", [2.int32] of ASTNode), "<=", [3.int32] of ASTNode)
  it_parses "1 == 2 == 3 == 4", Call.new(Call.new(Call.new(1.int32, "==", [2.int32] of ASTNode), "==", [3.int32] of ASTNode), "==", [4.int32] of ASTNode)

  it_parses "-> do end", FunLiteral.new
  it_parses "-> { }", FunLiteral.new
  it_parses "->() { }", FunLiteral.new
  it_parses "->(x : Int32) { }", FunLiteral.new(Def.new("->", [Arg.new("x", nil, "Int32".path)]))
  it_parses "->(x : Int32) { x }", FunLiteral.new(Def.new("->", [Arg.new("x", nil, "Int32".path)], "x".var))
  it_parses "->(x) { x }", FunLiteral.new(Def.new("->", [Arg.new("x")], "x".var))
  it_parses "x = 1; ->{ x }", [Assign.new("x".var, 1.int32), FunLiteral.new(Def.new("->", [] of Arg, "x".var))]

  it_parses "->foo", FunPointer.new(nil, "foo")
  it_parses "->Foo.foo", FunPointer.new("Foo".path, "foo")
  it_parses "->Foo::Bar::Baz.foo", FunPointer.new(["Foo", "Bar", "Baz"].path, "foo")
  it_parses "->foo(Int32, Float64)", FunPointer.new(nil, "foo", ["Int32".path, "Float64".path] of ASTNode)
  it_parses "foo = 1; ->foo.bar(Int32)", [Assign.new("foo".var, 1.int32), FunPointer.new("foo".var, "bar", ["Int32".path] of ASTNode)]
  it_parses "->foo(Void*)", FunPointer.new(nil, "foo", ["Void".path.pointer_of] of ASTNode)
  it_parses "call ->foo", Call.new(nil, "call", [FunPointer.new(nil, "foo")] of ASTNode)
  it_parses "[] of ->\n", ArrayLiteral.new([] of ASTNode, Fun.new)

  it_parses "foo.bar = {} of Int32 => Int32", Call.new("foo".call, "bar=", [HashLiteral.new([] of ASTNode, [] of ASTNode, "Int32".path, "Int32".path)] of ASTNode)

  it_parses "alias Foo = Bar", Alias.new("Foo", "Bar".path)

  it_parses "foo = 1; foo->bar->baz->coco", [Assign.new("foo".var, 1.int32), IndirectRead.new("foo".var, ["bar", "baz", "coco"])] of ASTNode
  it_parses "foo = 1; foo->bar->baz->coco = 1", [Assign.new("foo".var, 1.int32), IndirectWrite.new("foo".var, ["bar", "baz", "coco"], 1.int32)] of ASTNode

  it_parses "@foo->bar->baz->coco", IndirectRead.new("@foo".instance_var, ["bar", "baz", "coco"])
  it_parses "@foo->bar->baz->coco = 1", IndirectWrite.new("@foo".instance_var, ["bar", "baz", "coco"], 1.int32)

  it_parses "def foo\n1\nend\nif 1\nend", [Def.new("foo", [] of Arg, 1.int32), If.new(1.int32)] of ASTNode

  it_parses "1 as Bar", Cast.new(1.int32, "Bar".path)
  it_parses "foo as Bar", Cast.new("foo".call, "Bar".path)
  it_parses "foo.bar as Bar", Cast.new(Call.new("foo".call, "bar"), "Bar".path)

  it_parses "typeof(1)", TypeOf.new([1.int32] of ASTNode)

  it_parses "puts ~1", Call.new(nil, "puts", [Call.new(1.int32, "~")] of ASTNode)

  it_parses "foo\n.bar", Call.new("foo".call, "bar")
  it_parses "foo\n   .bar", Call.new("foo".call, "bar")
  it_parses "foo\n\n  .bar", Call.new("foo".call, "bar")
  it_parses "foo\n  #comment\n  .bar", Call.new("foo".call, "bar")

  it_parses "{1}", TupleLiteral.new([1.int32] of ASTNode)
  it_parses "{1, 2, 3}", TupleLiteral.new([1.int32, 2.int32, 3.int32] of ASTNode)
  it_parses "{A::B}", TupleLiteral.new([Path.new(["A", "B"])] of ASTNode)
  it_parses "{\n1,\n2\n}", TupleLiteral.new([1.int32, 2.int32] of ASTNode)

  it_parses "foo { a = 1 }; a", [Call.new(nil, "foo", [] of ASTNode, Block.new([] of Var, Assign.new("a".var, 1.int32))), "a".call] of ASTNode

  it_parses "lib C; ifdef foo; $foo : Int32; else; $foo : Float64; end; end", LibDef.new("C", nil, IfDef.new("foo".var, ExternalVar.new("foo", "Int32".path), ExternalVar.new("foo", "Float64".path)))

  it_parses "foo.bar(1).baz", Call.new(Call.new("foo".call, "bar", [1.int32] of ASTNode), "baz")

  it_parses "b.c ||= 1", Or.new(Call.new("b".call, "c"), Call.new("b".call, "c=", [1.int32] of ASTNode))
  it_parses "b.c &&= 1", And.new(Call.new("b".call, "c"), Call.new("b".call, "c=", [1.int32] of ASTNode))

  it_parses "a = 1; class Foo; @x = a; end", [Assign.new("a".var, 1.int32), ClassDef.new("Foo".path, Assign.new("@x".instance_var, "a".call))]

  it_parses "undef foo", Undef.new("foo")

  it_parses "@:Foo", Attribute.new("Foo")
  it_parses "@:Foo\n@:Bar", [Attribute.new("Foo"), Attribute.new("Bar")] of ASTNode

  it_parses "lib C\n@:Bar;end", LibDef.new("C", nil, [Attribute.new("Bar")] of ASTNode)

  %w(def macro class struct module fun alias abstract include extend lib).each do |keyword|
    it_parses "def foo\n#{keyword}\nend", Def.new("foo", [] of Arg, [keyword.call] of ASTNode)
  end

  it "keeps instance variables declared in def" do
    node = Parser.parse("def foo; @x = 1; @y = 2; @x = 3; @z; end") as Def
    node.instance_vars.should eq(Set.new(["@x", "@y"]))
  end

  it "keeps instance variables declared in def in multi-assign" do
    node = Parser.parse("def foo; @x, @y = 1, 2; end") as Def
    node.instance_vars.should eq(Set.new(["@x", "@y"]))
  end

  it "keeps instance variables declared in def with ||= and &&=" do
    node = Parser.parse("def foo; @x ||= 1; @y &&= 1; end") as Def
    node.instance_vars.should eq(Set.new(["@x", "@y"]))
  end

  it "keeps instance variables declared in def with declare var" do
    node = Parser.parse("def foo; @x :: Int32; end") as Def
    node.instance_vars.should eq(Set.new(["@x"]))
  end

  assert_syntax_error "def foo(x = 1, y); end",
                      "argument must have a default value"

  assert_syntax_error " [1, 2, 3 end",
                      "unterminated array literal", 1, 2

  assert_syntax_error " {1 => end",
                      "unterminated hash literal", 1, 2

  assert_syntax_error " {1, 2, 3 end",
                      "unterminated tuple literal", 1, 2

  assert_syntax_error " (1, 2, 3 end",
                      "unterminated parenthesized expression", 1, 2

  assert_syntax_error "foo(1, 2, 3 end",
                      "unterminated call", 1, 4

  assert_syntax_error "foo(foo(&.block)",
                      "unterminated call", 1, 4

  assert_syntax_error "case when .foo? then 1; end"
  assert_syntax_error "macro foo;{%end};end"
  assert_syntax_error "foo {1, 2}", "unexpected token: }"
  assert_syntax_error "pointerof(self)", "can't take pointerof(self)"
  assert_syntax_error "def foo 1; end"
end
