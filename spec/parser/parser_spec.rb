require 'spec_helper'

describe Parser do
  def self.it_parses(string, expected_node, options = {})
    it "parses #{string}", options do
      node = Parser.parse(string)
      node.should eq(Expressions.from expected_node)
    end
  end

  it_parses "nil", NilLiteral.new

  it_parses "true", true.bool
  it_parses "false", false.bool

  it_parses "1", 1.int32
  it_parses "+1", 1.int32
  it_parses "-1", -1.int32

  it_parses "1_i64", 1.int64
  it_parses "+1_i64", 1.int64
  it_parses "-1_i64", -1.int64

  it_parses "1.0_f32", 1.0.float32
  it_parses "+1.0_f32", 1.0.float32
  it_parses "-1.0_f32", -1.0.float32

  it_parses "1.0", 1.0.float64
  it_parses "+1.0", 1.0.float64
  it_parses "-1.0", -1.0.float64
  it_parses "-1.0_f64", -1.0.float64

  it_parses "'a'", CharLiteral.new(?a.ord)

  it_parses %("foo"), StringLiteral.new("foo")
  it_parses %(""), StringLiteral.new("")
  it_parses ":foo", SymbolLiteral.new("foo")
  it_parses "puts :foo.to_s", Call.new(nil, 'puts', [Call.new(SymbolLiteral.new("foo"), "to_s")])

  it_parses "[1, 2]", [1.int32, 2.int32].array
  it_parses "[\n1, 2]", [1.int32, 2.int32].array
  it_parses "[1,\n 2,]", [1.int32, 2.int32].array
  it_parses "%w(one two three)", ["one".string, "two".string, "three".string].array

  it_parses "[] of Int", [].array_of(Ident.new(["Int"]))
  it_parses "[1, 2] of Int", [1.int32, 2.int32].array_of(Ident.new(["Int"]))

  it_parses "-x", Call.new("x".call, :"-@")
  it_parses "+x", Call.new("x".call, :"+@")
  it_parses "+ 1", Call.new(1.int32, :"+@")

  it_parses "1 + 2", Call.new(1.int32, :"+", [2.int32])
  it_parses "1 +\n2", Call.new(1.int32, :"+", [2.int32])
  it_parses "1 +2", Call.new(1.int32, :"+", [2.int32])
  it_parses "1 -2", Call.new(1.int32, :"-", [2.int32])
  it_parses "1 +2.0", Call.new(1.int32, :"+", [2.float64])
  it_parses "1 -2.0", Call.new(1.int32, :"-", [2.float64])
  it_parses "1 + 2_i64", Call.new(1.int32, :"+", [2.int64])
  it_parses "1 -2_i64", Call.new(1.int32, :"-", [2.int64])
  it_parses "1\n+2", [1.int32, 2.int32]
  it_parses "1;+2", [1.int32, 2.int32]
  it_parses "1 - 2", Call.new(1.int32, :"-", [2.int32])
  it_parses "1 -\n2", Call.new(1.int32, :"-", [2.int32])
  it_parses "1\n-2", [1.int32, -2.int32]
  it_parses "1;-2", [1.int32, -2.int32]
  it_parses "1 * 2", Call.new(1.int32, :"*", [2.int32])
  it_parses "1 * -2", Call.new(1.int32, :"*", [-2.int32])
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int32, :"*", [3.int32]), :"+", [Call.new(4.int32, :"*", [5.int32])])
  it_parses "1 / 2", Call.new(1.int32, :"/", [2.int32])
  it_parses "1 / -2", Call.new(1.int32, :"/", [-2.int32])
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int32, :"/", [3.int32]), :"+", [Call.new(4.int32, :"/", [5.int32])])
  it_parses "2 * (3 + 4)", Call.new(2.int32, :"*", [Call.new(3.int32, :"+", [4.int32])])

  it_parses "!1", Call.new(1.int32, :'!@')
  it_parses "1 && 2", And.new(1.int32, 2.int32)
  it_parses "1 || 2", Or.new(1.int32, 2.int32)

  it_parses "1 <=> 2", Call.new(1.int32, :"<=>", [2.int32])

  it_parses "a = 1", Assign.new("a".var, 1.int32)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int32))

  it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var], [1.int32, 2.int32])
  it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var], [1.int32])

  it_parses "a = 1; A = a", [Assign.new("a".var, 1.int32), Assign.new("A".ident, "a".call)]

  it_parses "def foo\n1\nend", Def.new("foo", [], [1.int32])
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".arg], [1.int32])
  it_parses "def foo ; 1 ; end", Def.new("foo", [], [1.int32])
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
  it_parses "def foo; 1; 2; end", Def.new("foo", [], [1.int32, 2.int32])
  it_parses "def foo=(value); end", Def.new("foo=", ["value".arg], [])
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".arg], "foo".call(Call.new("n".var, :-, [1.int32])))
  it_parses "def type(type); end", Def.new(:type, ["type".arg], nil)

  it_parses "def self.foo\n1\nend", Def.new("foo", [], [1.int32], "self".var)
  it_parses "def self.foo=(value); end", Def.new("foo=", ["value".arg], [], "self".var)
  it_parses "def Foo.foo\n1\nend", Def.new("foo", [], [1.int32], "Foo".ident)
  it_parses "def Foo::Bar.foo\n1\nend", Def.new("foo", [], [1.int32], ['Foo', 'Bar'].ident)

  it_parses "def foo; a; end", Def.new('foo', [], ["a".call])
  it_parses "def foo(a); a; end", Def.new('foo', ['a'.arg], ["a".var])
  it_parses "def foo; a = 1; a; end", Def.new('foo', [], [Assign.new('a'.var, 1.int32), 'a'.var])
  it_parses "def foo; a = 1; a {}; end", Def.new('foo', [], [Assign.new('a'.var, 1.int32), Call.new(nil, "a", [], Block.new)])
  it_parses "def foo; a = 1; x { a }; end", Def.new('foo', [], [Assign.new('a'.var, 1.int32), Call.new(nil, "x", [], Block.new([], ['a'.var]))])
  it_parses "def foo; x { |a| a }; end", Def.new('foo', [], [Call.new(nil, "x", [], Block.new(['a'.var], ['a'.var]))])

  it_parses "def foo(var = 1); end", Def.new("foo", [Arg.new("var", 1.int32)], nil)
  it_parses "def foo var = 1; end", Def.new("foo", [Arg.new("var", 1.int32)], nil)
  it_parses "def foo(var : Int); end", Def.new("foo", [Arg.new("var", nil, 'Int'.ident)], nil)
  it_parses "def foo var : Int; end", Def.new("foo", [Arg.new("var", nil, 'Int'.ident)], nil)
  it_parses "def foo(var : self); end", Def.new("foo", [Arg.new("var", nil, SelfType.instance)], nil)
  it_parses "def foo var : self; end", Def.new("foo", [Arg.new("var", nil, SelfType.instance)], nil)
  it_parses "def foo(var : Int | Double); end", Def.new("foo", [Arg.new("var", nil, IdentUnion.new(['Int'.ident, 'Double'.ident]))], nil)
  it_parses "def foo(var : Int?); end", Def.new("foo", [Arg.new("var", nil, IdentUnion.new(['Int'.ident, 'Nil'.ident(true)]))], nil)
  it_parses "def foo(var : Int*); end", Def.new("foo", [Arg.new("var", nil, NewGenericClass.new(Ident.new(["Pointer"], true), ["Int".ident]))], nil)
  it_parses "def foo(var = 1 : Int32); end", Def.new("foo", [Arg.new("var", 1.int32, "Int32".ident)], nil)
  it_parses "def foo; yield; end", Def.new("foo", [], [Yield.new], nil, nil, 0)
  it_parses "def foo; yield 1; end", Def.new("foo", [], [Yield.new([1.int32])], nil, nil, 1)
  it_parses "def foo; yield 1; yield; end", Def.new("foo", [], [Yield.new([1.int32]), Yield.new], nil, nil, 1)
  it_parses "def foo(a, b = a); end", Def.new("foo", [Arg.new("a"), Arg.new("b", "a".var)], nil)
  it_parses "def foo(a, &block); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block"))
  it_parses "def foo(a, &block : Int -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", ["Int".ident], "Double".ident))
  it_parses "def foo(a, &block : Int, Float -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", ["Int".ident, "Float".ident], "Double".ident))
  it_parses "def foo(a, &block : -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", nil, "Double".ident))
  it_parses "def foo(a, &block : Int -> ); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", ["Int".ident]))
  it_parses "def foo(a, &block : self -> self); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", [SelfType.instance], SelfType.instance))
  it_parses "def foo; a.yield; end", Def.new("foo", [], [Yield.new([], "a".call)], nil, nil, 1)
  it_parses "def foo; a.yield 1; end", Def.new("foo", [], [Yield.new([1.int32], "a".call)], nil, nil, 1)
  it_parses "def foo(@var); end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var)])
  it_parses "def foo(@var); 1; end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var), 1.int32])
  it_parses "def foo(@var = 1); 1; end", Def.new("foo", [Arg.new("var", 1.int32)], [Assign.new("@var".instance_var, "var".var), 1.int32])

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call(1.int32)
  it_parses "foo 1", "foo".call(1.int32)
  it_parses "foo 1\n", "foo".call(1.int32)
  it_parses "foo 1;", "foo".call(1.int32)
  it_parses "foo 1, 2", "foo".call(1.int32, 2.int32)
  it_parses "foo (1 + 2), 3", "foo".call(Call.new(1.int32, :"+", [2.int32]), 3.int32)
  it_parses "foo(1 + 2)", "foo".call(Call.new(1.int32, :"+", [2.int32]))
  it_parses "foo -1.0, -2.0", "foo".call(-1.float64, -2.float64)
  it_parses "foo(\n1)", "foo".call(1.int32)
  it_parses "::foo", Call.new(nil, "foo", [], nil, true)

  it_parses "foo + 1", Call.new("foo".call, :"+", [1.int32])
  it_parses "foo +1", Call.new(nil, "foo", [1.int32])
  it_parses "foo +1.0", Call.new(nil, "foo", [1.float64])
  it_parses "foo +1_i64", Call.new(nil, "foo", [1.int64])
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, :+, [1.int32])]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, :-, [1.int32])]

  it_parses "foo !false", Call.new(nil, "foo", [Call.new(false.bool, :'!@')])
  it_parses "!a && b", And.new(Call.new("a".call, :'!@'), "b".call)

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".ident, "new")])
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".ident, "new")])
  it_parses "f.x = - 1", Call.new("f".call, "x=", [Call.new(1.int32, :'-@')])

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>].each do |op|
    it_parses "f.x #{op}= 2", Call.new("f".call, "x=", [Call.new(Call.new("f".call, "x"), op, [2.int32])])
  end

  ["=", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "%", "&", "|", "^", "**", "+@", "-@", "~@", "!@", '==='].each do |op|
    it_parses "def #{op}; end;", Def.new(op.to_sym, [], nil)
  end

  it_parses "def %(); end;", Def.new(:'%', [], nil)

  ['<<', '<', '<=', '==', '>>', '>', '>=', '+', '-', '*', '/', '%', '|', '&', '^', '**', '==='].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int32, op.to_sym, [2.int32])
    it_parses "n #{op} 2", Call.new("n".call, op.to_sym, [2.int32])
  end

  ['bar', :'+', :'-', :'*', :'/', :'<', :'<=', :'==', :'>', :'>=', :'%', :'|', :'&', :'^', :'**', :'==='].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, [1.int32, 2.int32])
  end

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>].each do |op|
    it_parses "a = 1; a #{op}= 1", [Assign.new("a".var, 1.int32), Assign.new("a".var, Call.new("a".var, op.to_sym, [1.int32]))]
    it_parses "a = 1; a[2] #{op}= 3", [Assign.new("a".var, 1.int32), Call.new("a".var, :"[]=", [2.int32, Call.new(Call.new("a".var, :"[]", [2.int32]), op.to_sym, [3.int32])])]
  end

  it_parses "a = 1; a &&= 1", [Assign.new("a".var, 1.int32), And.new("a".var, Assign.new("a".var, 1.int32))]
  it_parses "a = 1; a ||= 1", [Assign.new("a".var, 1.int32), Or.new("a".var, Assign.new("a".var, 1.int32))]

  it_parses "a = 1; a[2] &&= 3", [Assign.new("a".var, 1.int32), And.new(Call.new("a".var, :"[]", [2.int32]), Call.new("a".var, :"[]=", [2.int32, 3.int32]))]
  it_parses "a = 1; a[2] ||= 3", [Assign.new("a".var, 1.int32), Or.new(Call.new("a".var, :"[]", [2.int32]), Call.new("a".var, :"[]=", [2.int32, 3.int32]))]

  it_parses "if foo; 1; end", If.new("foo".call, 1.int32)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int32)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int32, If.new("bar".call, 2.int32, 3.int32))

  it_parses "include Foo", Include.new("Foo".ident)
  it_parses "include Foo\nif true; end", [Include.new("Foo".ident), If.new(true.bool)]

  it_parses "unless foo; 1; end", Unless.new("foo".call, 1.int32)
  it_parses "unless foo; 1; else; 2; end", Unless.new("foo".call, 1.int32, 2.int32)

  it_parses "class Foo; end", ClassDef.new("Foo".ident)
  it_parses "class Foo\nend", ClassDef.new("Foo".ident)
  it_parses "class Foo\ndef foo; end; end", ClassDef.new("Foo".ident, [Def.new("foo", [], nil)])
  it_parses "class Foo < Bar; end", ClassDef.new("Foo".ident, nil, "Bar".ident)
  it_parses "class Foo(T); end", ClassDef.new("Foo".ident, nil, nil, ["T"])
  it_parses "abstract class Foo; end", ClassDef.new("Foo".ident, nil, nil, nil, true)
  it_parses "class Foo::Bar; end", ClassDef.new(Ident.new(["Foo", "Bar"]))

  it_parses "Foo(T)", NewGenericClass.new("Foo".ident, ["T".ident])
  it_parses "Foo(T | U)", NewGenericClass.new("Foo".ident, [IdentUnion.new(["T".ident, "U".ident])])
  it_parses "Foo(Bar(T | U))", NewGenericClass.new("Foo".ident, [NewGenericClass.new("Bar".ident, [IdentUnion.new(["T".ident, "U".ident])])])
  it_parses "Foo(T?)", NewGenericClass.new("Foo".ident, [IdentUnion.new(["T".ident, Ident.new(["Nil"], true)])])

  it_parses "module Foo; end", ModuleDef.new("Foo".ident)
  it_parses "module Foo\ndef foo; end; end", ModuleDef.new("Foo".ident, [Def.new("foo", [], nil)])
  it_parses "module Foo(T); end", ModuleDef.new("Foo".ident, nil, ["T"])

  it_parses "while true; 1; end;", While.new(true.bool, 1.int32)

  it_parses "foo do; 1; end", Call.new(nil, "foo", [], Block.new([], 1.int32))
  it_parses "foo do |a|; 1; end", Call.new(nil, "foo", [], Block.new(["a".var], 1.int32))

  it_parses "foo { 1 }", Call.new(nil, "foo", [], Block.new([], 1.int32))
  it_parses "foo { |a| 1 }", Call.new(nil, "foo", [], Block.new(["a".var], 1.int32))
  it_parses "foo { |a, b| 1 }", Call.new(nil, "foo", [], Block.new(["a".var, "b".var], 1.int32))
  it_parses "1.foo do; 1; end", Call.new(1.int32, "foo", [], Block.new([], 1.int32))

  it_parses "1 ? 2 : 3", If.new(1.int32, 2.int32, 3.int32)
  it_parses "1 ? a : b", If.new(1.int32, "a".call, "b".call)

  it_parses "1 if 3", If.new(3.int32, 1.int32)
  it_parses "1 unless 3", Unless.new(3.int32, 1.int32)
  it_parses "1 while 3", While.new(3.int32, 1.int32, true)
  it_parses "a = 1; a += 10 if a += 20", [Assign.new("a".var, 1.int32), If.new(Assign.new("a".var, Call.new("a".var, :+, [20.int32])), Assign.new("a".var, Call.new("a".var, :+, [10.int32])))]
  it_parses "puts a if true", If.new(true.bool, Call.new(nil, 'puts', ["a".call]))
  it_parses "puts a unless true", Unless.new(true.bool, Call.new(nil, 'puts', ["a".call]))
  it_parses "puts a while true", While.new(true.bool, Call.new(nil, 'puts', ["a".call]), true)

  ['return', 'next', 'break', 'yield'].each do |keyword|
    it_parses "#{keyword}", eval(keyword.capitalize).new
    it_parses "#{keyword};", eval(keyword.capitalize).new
    it_parses "#{keyword} 1", eval(keyword.capitalize).new([1.int32])
    it_parses "#{keyword} 1 if true", If.new(true.bool, eval(keyword.capitalize).new([1.int32]))
    it_parses "#{keyword} if true", If.new(true.bool, eval(keyword.capitalize).new)
  end

  it_parses "Int", "Int".ident

  it_parses "Int[]", Call.new("Int".ident, :[])
  it_parses "def []; end", Def.new(:[], [], nil)
  it_parses "def []?; end", Def.new(:"[]?", [], nil)
  it_parses "def []=(value); end", Def.new(:[]=, ["value".arg], nil)
  it_parses "def self.[]; end", Def.new(:[], [], nil, "self".var)

  it_parses "Int[8]", Call.new("Int".ident, :[], [8.int32])
  it_parses "Int[8, 4]", Call.new("Int".ident, :[], [8.int32, 4.int32])
  it_parses "Int[8, 4,]", Call.new("Int".ident, :[], [8.int32, 4.int32])
  it_parses "Int[8]?", Call.new("Int".ident, :"[]?", [8.int32])

  it_parses "def [](x); end", Def.new(:[], ["x".arg], nil)

  it_parses "foo[0] = 1", Call.new("foo".call, :[]=, [0.int32, 1.int32])

  it_parses "begin; 1; 2; 3; end;", Expressions.new([1.int32, 2.int32, 3.int32])

  it_parses "self", "self".var

  it_parses "@foo", "@foo".instance_var
  it_parses "@foo = 1", Assign.new("@foo".instance_var, 1.int32)
  it_parses "-@foo", Call.new("@foo".instance_var, :-@)

  it_parses "@@foo", "@@foo".class_var
  it_parses "@@foo = 1", Assign.new("@@foo".class_var, 1.int32)
  it_parses "-@@foo", Call.new("@@foo".class_var, :-@)

  it_parses "puts @@x", Call.new(nil, "puts", ['@@x'.class_var])

  it_parses "call @foo.bar", Call.new(nil, "call", [Call.new("@foo".instance_var, "bar")])
  it_parses 'call "foo"', Call.new(nil, "call", ["foo".string])

  it_parses "def foo; end; if false; 1; else; 2; end", [Def.new('foo', []), If.new(false.bool, 1.int32, 2.int32)]

  it_parses %Q(A.new("x", B.new("y"))), Call.new("A".ident, "new", ["x".string, Call.new("B".ident, "new", ["y".string])])

  it_parses "foo [1]", Call.new(nil, "foo", [[1.int32].array])
  it_parses "foo.bar [1]", Call.new("foo".call, "bar", [[1.int32].array])

  it_parses "class Foo; end\nwhile true; end", [ClassDef.new("Foo".ident), While.new(true.bool)]
  it_parses "while true; end\nif true; end", [While.new(true.bool), If.new(true.bool)]
  it_parses "(1)\nif true; end", [1.int32, If.new(true.bool)]
  it_parses "begin\n1\nend\nif true; end", [1.int32, If.new(true.bool)]

  it_parses "Foo::Bar", ['Foo', 'Bar'].ident

  it_parses "lib C\nend", LibDef.new('C')
  it_parses %Q(lib C("libc")\nend), LibDef.new('C', 'libc')
  it_parses "lib C\nfun getchar\nend", LibDef.new('C', nil, [FunDef.new('getchar')])
  it_parses "lib C\nfun getchar(...)\nend", LibDef.new('C', nil, [FunDef.new('getchar', [], nil, 0, true)])
  it_parses "lib C\nfun getchar : Int\nend", LibDef.new('C', nil, [FunDef.new('getchar', [], 'Int'.ident)])
  it_parses "lib C\nfun getchar(a : Int, b : Float)\nend", LibDef.new('C', nil, [FunDef.new('getchar', [FunDefArg.new('a', 'Int'.ident), FunDefArg.new('b', 'Float'.ident)])])
  it_parses "lib C\nfun getchar(a : Int)\nend", LibDef.new('C', nil, [FunDef.new('getchar', [FunDefArg.new('a', 'Int'.ident, 0)])])
  it_parses "lib C\nfun getchar(a : Int, b : Float) : Int\nend", LibDef.new('C', nil, [FunDef.new('getchar', [FunDefArg.new('a', 'Int'.ident), FunDefArg.new('b', 'Float'.ident)], 'Int'.ident)])
  it_parses "lib C; fun getchar(a : Int, b : Float) : Int; end", LibDef.new('C', nil, [FunDef.new('getchar', [FunDefArg.new('a', 'Int'.ident), FunDefArg.new('b', 'Float'.ident)], 'Int'.ident)])
  it_parses "lib C; fun foo(a : Int*); end", LibDef.new('C', nil, [FunDef.new('foo', [FunDefArg.new('a', 'Int'.ident, 1)])])
  it_parses "lib C; fun foo(a : Int**); end", LibDef.new('C', nil, [FunDef.new('foo', [FunDefArg.new('a', 'Int'.ident, 2)])])
  it_parses "lib C; fun foo : Int*; end", LibDef.new('C', nil, [FunDef.new('foo', [], 'Int'.ident, 1)])
  it_parses "lib C; fun foo : Int**; end", LibDef.new('C', nil, [FunDef.new('foo', [], 'Int'.ident, 2)])
  it_parses "lib C; type A : B; end", LibDef.new('C', nil, [TypeDef.new('A', 'B'.ident)])
  it_parses "lib C; type A : B*; end", LibDef.new('C', nil, [TypeDef.new('A', 'B'.ident, 1)])
  it_parses "lib C; type A : B**; end", LibDef.new('C', nil, [TypeDef.new('A', 'B'.ident, 2)])
  it_parses "lib C; struct Foo; end end", LibDef.new('C', nil, [StructDef.new('Foo')])
  it_parses "lib C; struct Foo; x : Int; y : Float; end end", LibDef.new('C', nil, [StructDef.new('Foo', [FunDefArg.new('x', 'Int'.ident), FunDefArg.new('y', 'Float'.ident)])])
  it_parses "lib C; struct Foo; x : Int*; end end", LibDef.new('C', nil, [StructDef.new('Foo', [FunDefArg.new('x', 'Int'.ident, 1)])])
  it_parses "lib C; struct Foo; x : Int**; end end", LibDef.new('C', nil, [StructDef.new('Foo', [FunDefArg.new('x', 'Int'.ident, 2)])])
  it_parses "lib C; struct Foo; x, y, z : Int; end end", LibDef.new('C', nil, [StructDef.new('Foo', [FunDefArg.new('x', 'Int'.ident), FunDefArg.new('y', 'Int'.ident), FunDefArg.new('z', 'Int'.ident)])])
  it_parses "lib C; union Foo; end end", LibDef.new('C', nil, [UnionDef.new('Foo')])
  it_parses "lib C; enum Foo; A\nB, C\nD = 1; end end", LibDef.new('C', nil, [EnumDef.new('Foo', [Arg.new('A'), Arg.new('B'), Arg.new('C'), Arg.new('D', 1.int32)])])
  it_parses "lib C; enum Foo; A = 1, B; end end", LibDef.new('C', nil, [EnumDef.new('Foo', [Arg.new('A', 1.int32), Arg.new('B')])])
  it_parses "lib C; Foo = 1; end", LibDef.new('C', nil, [Assign.new("Foo".ident, 1.int32)])
  it_parses "lib C\nfun getch = GetChar\nend", LibDef.new('C', nil, [FunDef.new('getch', [], nil, 0, false, nil, 'GetChar')])
  it_parses "lib C\n$errno : Int32\n$errno2 : Int32\nend", LibDef.new("C", nil, [FunDefArg.new("errno", "Int32".ident), FunDefArg.new("errno2", "Int32".ident)])

  it_parses "fun foo(x : Int32) : Int64\nx\nend", FunDef.new("foo", [FunDefArg.new("x", "Int32".ident)], "Int64".ident, 0, false, "x".var)

  it_parses "1 .. 2", RangeLiteral.new(1.int32, 2.int32, false)
  it_parses "1 ... 2", RangeLiteral.new(1.int32, 2.int32, true)

  it_parses "A = 1", Assign.new("A".ident, 1.int32)

  it_parses "puts %w(one)", Call.new(nil, 'puts', [['one'.string].array])

  it_parses "::A::B", Ident.new(['A', 'B'], true)

  it_parses "$foo", Global.new('$foo')

  it_parses "macro foo;end", Macro.new('foo', [])

  it_parses "a = 1; a.ptr", [Assign.new("a".var, 1.int32), PointerOf.new('a'.var)]
  it_parses "@a.ptr", PointerOf.new('@a'.instance_var)

  it_parses "foo.is_a?(Const)", IsA.new("foo".call, "Const".ident)
  it_parses "foo.responds_to?(:foo)", RespondsTo.new("foo".call, "foo".symbol)

  it_parses "/foo/", RegexpLiteral.new("foo")

  it_parses "1 =~ 2", Call.new(1.int32, :=~, [2.int32])
  it_parses "1.=~(2)", Call.new(1.int32, :=~, [2.int32])
  it_parses "def =~; end", Def.new(:=~, [])

  it_parses "foo $a", Call.new(nil, 'foo', [Global.new('$a')])

  it_parses "$1", Call.new(Global.new('$~'), :[], [1.int32])
  it_parses "foo $1", Call.new(nil, 'foo', [Call.new(Global.new('$~'), :[], [1.int32])])
  it_parses "foo /a/", Call.new(nil, 'foo', [RegexpLiteral.new('a')])

  it_parses "foo out x; x", [Call.new(nil, 'foo', [Var.new('x').tap { |v| v.out = true }]), Var.new('x')]
  it_parses "foo(out x); x", [Call.new(nil, 'foo', [Var.new('x').tap { |v| v.out = true }]), Var.new('x')]

  it_parses "{1 => 2, 3 => 4}", HashLiteral.new([1.int32, 3.int32], [2.int32, 4.int32])
  it_parses "{a: 1, b: 2}", HashLiteral.new(['a'.symbol, 'b'.symbol], [1.int32, 2.int32])
  it_parses "{a: 1, 3 => 4, b: 2}", HashLiteral.new(['a'.symbol, 3.int32, 'b'.symbol], [1.int32, 4.int32, 2.int32])

  it_parses "{} of Int => Double", HashLiteral.new([], [], Ident.new(["Int"]), Ident.new(["Double"]))

  it_parses %q(require "foo"), Require.new('foo')
  it_parses %q(require "foo"; [1]), [Require.new('foo'), [1.int32].array]
  it_parses %Q(require "foo"\nif true; end), [Require.new('foo'), If.new(true.bool)]

  it_parses %q(require "foo" if (!a || b) && c), [Require.new("foo", And.new(Or.new(Not.new("a".var), "b".var), "c".var))]
  it_parses %q(require "foo" if !(a || b) && c), [Require.new("foo", And.new(Not.new(Or.new("a".var, "b".var)), "c".var))]

  it_parses %q(case 1; when 1; 2; else; 3; end), Case.new(1.int32, [When.new([1.int32], 2.int32)], 3.int32)
  it_parses %q(case 1; when 0, 1; 2; else; 3; end), Case.new(1.int32, [When.new([0.int32, 1.int32], 2.int32)], 3.int32)
  it_parses %Q(case 1\nwhen 1\n2\nelse\n3\nend), Case.new(1.int32, [When.new([1.int32], 2.int32)], 3.int32)
  it_parses %Q(case 1\nwhen 1\n2\nend), Case.new(1.int32, [When.new([1.int32], 2.int32)])

  it_parses %q(case 1; when 1 then 2; else; 3; end), Case.new(1.int32, [When.new([1.int32], 2.int32)], 3.int32)
  it_parses %Q(case 1\nwhen 1\n2\nend\nif a\nend), [Case.new(1.int32, [When.new([1.int32], 2.int32)]), If.new('a'.call)]

  it_parses "def foo(x); end; x", [Def.new("foo", ["x".arg]), "x".call]

  it_parses %q("foo#{bar}baz"), StringInterpolation.new([StringLiteral.new("foo"), "bar".call, StringLiteral.new("baz")])

  it_parses %Q(lib Foo\nend\nif true\nend), [LibDef.new("Foo"), If.new(true.bool)]

  it_parses "foo(\n1\n)", Call.new(nil, "foo", [1.int32])
  it_parses "a = 1\nfoo - a", [Assign.new("a".var, 1.int32), Call.new("foo".call, :-, ["a".var])]
  it_parses "a = 1\nfoo -a", [Assign.new("a".var, 1.int32), Call.new(nil, "foo", [Call.new("a".var, :-@)])]

  it_parses "a :: Foo", DeclareVar.new("a", "Foo".ident)

  it_parses "()", NilLiteral.new
  it_parses "(1; 2; 3)", [1.int32, 2.int32, 3.int32]

  it_parses "begin; rescue; end", ExceptionHandler.new(nil, [Rescue.new])
  it_parses "begin; 1; rescue; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])
  it_parses "begin; 1; ensure; 2; end", ExceptionHandler.new(1.int32, nil, nil, 2.int32)
  it_parses "begin\n1\nensure\n2\nend", ExceptionHandler.new(1.int32, nil, nil, 2.int32)
  it_parses "begin; 1; rescue Foo; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".ident])])
  it_parses "begin; 1; rescue Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".ident, "Bar".ident])])
  it_parses "begin; 1; rescue ex : Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".ident, "Bar".ident], "ex")])
  it_parses "begin; 1; rescue ex; ex; end", ExceptionHandler.new(1.int32, [Rescue.new("ex".var, nil, "ex")])
  it_parses "begin; 1; rescue; 2; else; 3; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)], 3.int32)

  it_parses "def foo; 1; rescue; 2; end", Def.new("foo", [], ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))
  it_parses "fun foo; 1; rescue; 2; end", FunDef.new("foo", [], nil, 0, false, ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))

  it_parses "1 rescue 2", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])

  it_parses "1 <= 2 <= 3", And.new(Call.new(1.int32, :"<=", [2.int32]), Call.new(2.int32, :"<=", [3.int32]))
  it_parses "1 == 2 == 3 == 4", And.new(And.new(Call.new(1.int32, :"==", [2.int32]), Call.new(2.int32, :"==", [3.int32])), Call.new(3.int32, :"==", [4.int32]))

  it_parses "-> do end", FunLiteral.new
  it_parses "-> { }", FunLiteral.new
  it_parses "->() { }", FunLiteral.new
  it_parses "->(x) { }", FunLiteral.new(Def.new("->", ["x".arg]))
  it_parses "->(x : Int32) { }", FunLiteral.new(Def.new("->", [Arg.new("x", nil, "Int32".ident)]))

  it_parses "->foo", FunPointer.new(nil, "foo")
  it_parses "->Foo.foo", FunPointer.new("Foo".ident, "foo")
  it_parses "->Foo::Bar::Baz.foo", FunPointer.new(["Foo", "Bar", "Baz"].ident, "foo")
  it_parses "->foo(Int32, Float64)", FunPointer.new(nil, "foo", ["Int32".ident, "Float64".ident])

  it "keeps instance variables declared in def" do
    node = Parser.parse("def foo; @x = 1; @y = 2; @x = 3; @z; end")
    node.instance_vars.should eq(Set.new(["@x", "@y", "@z"]))
  end

  it "is an error if multi assign count mismatch" do
    assert_syntax_error "a = 1, 2", "Multiple assignment count mismatch"
    assert_syntax_error "a, b, c = d, e", "Multiple assignment count mismatch"
  end
end
