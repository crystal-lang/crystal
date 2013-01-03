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

  it_parses "1", 1.int
  it_parses "+1", 1.int
  it_parses "-1", -1.int

  it_parses "1L", 1.long
  it_parses "+1L", 1.long
  it_parses "-1L", -1.long

  it_parses "1.0f", 1.0.float
  it_parses "+1.0f", 1.0.float
  it_parses "-1.0f", -1.0.float

  it_parses "1.0", 1.0.double
  it_parses "+1.0", 1.0.double
  it_parses "-1.0", -1.0.double

  it_parses "'a'", CharLiteral.new(?a.ord)

  it_parses %("foo"), StringLiteral.new("foo")
  it_parses %(""), StringLiteral.new("")
  it_parses ":foo", SymbolLiteral.new("foo")
  it_parses "puts :foo.to_s", Call.new(nil, 'puts', [Call.new(SymbolLiteral.new("foo"), "to_s")])

  it_parses "[]", [].array
  it_parses "[1, 2]", [1.int, 2.int].array
  it_parses "[\n1, 2]", [1.int, 2.int].array
  it_parses "[1,\n 2,]", [1.int, 2.int].array
  it_parses "%w(one two three)", ["one".string, "two".string, "three".string].array

  it_parses "-x", Call.new("x".call, :"-@")
  it_parses "+x", Call.new("x".call, :"+@")
  it_parses "+ 1", Call.new(1.int, :"+@")

  it_parses "1 + 2", Call.new(1.int, :"+", [2.int])
  it_parses "1 +\n2", Call.new(1.int, :"+", [2.int])
  it_parses "1 +2", Call.new(1.int, :"+", [2.int])
  it_parses "1 -2", Call.new(1.int, :"-", [2.int])
  it_parses "1 +2.0", Call.new(1.int, :"+", [2.double])
  it_parses "1 -2.0", Call.new(1.int, :"-", [2.double])
  it_parses "1 +2L", Call.new(1.int, :"+", [2.long])
  it_parses "1 -2L", Call.new(1.int, :"-", [2.long])
  it_parses "1\n+2", [1.int, 2.int]
  it_parses "1;+2", [1.int, 2.int]
  it_parses "1 - 2", Call.new(1.int, :"-", [2.int])
  it_parses "1 -\n2", Call.new(1.int, :"-", [2.int])
  it_parses "1\n-2", [1.int, -2.int]
  it_parses "1;-2", [1.int, -2.int]
  it_parses "1 * 2", Call.new(1.int, :"*", [2.int])
  it_parses "1 * -2", Call.new(1.int, :"*", [-2.int])
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int, :"*", [3.int]), :"+", [Call.new(4.int, :"*", [5.int])])
  it_parses "1 / 2", Call.new(1.int, :"/", [2.int])
  it_parses "1 / -2", Call.new(1.int, :"/", [-2.int])
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int, :"/", [3.int]), :"+", [Call.new(4.int, :"/", [5.int])])
  it_parses "2 * (3 + 4)", Call.new(2.int, :"*", [Call.new(3.int, :"+", [4.int])])

  it_parses "!1", Call.new(1.int, :'!@')
  it_parses "1 && 2", Call.new(1.int, :'&&', [2.int])
  it_parses "1 || 2", Call.new(1.int, :'||', [2.int])

  it_parses "1 <=> 2", Call.new(1.int, :"<=>", [2.int])

  it_parses "a = 1", Assign.new("a".var, 1.int)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int))

  it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var], [1.int, 2.int])
  it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var], [1.int])
  it_parses "a = 1, 2", MultiAssign.new(["a".var], [1.int, 2.int])

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
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".arg], "foo".call(Call.new("n".var, :-, [1.int])))
  it_parses "def type(type); end", Def.new(:type, ["type".arg], nil)

  it_parses "def self.foo\n1\nend", Def.new("foo", [], [1.int], "self".var)
  it_parses "def Foo.foo\n1\nend", Def.new("foo", [], [1.int], "Foo".ident)
  it_parses "def Foo::Bar.foo\n1\nend", Def.new("foo", [], [1.int], ['Foo', 'Bar'].ident)

  it_parses "def foo; a; end", Def.new('foo', [], ["a".call])
  it_parses "def foo(a); a; end", Def.new('foo', ['a'.arg], ["a".var])
  it_parses "def foo; a = 1; a; end", Def.new('foo', [], [Assign.new('a'.var, 1.int), 'a'.var])
  it_parses "def foo; a = 1; a {}; end", Def.new('foo', [], [Assign.new('a'.var, 1.int), Call.new(nil, "a", [], Block.new)])
  it_parses "def foo; a = 1; x { a }; end", Def.new('foo', [], [Assign.new('a'.var, 1.int), Call.new(nil, "x", [], Block.new([], ['a'.var]))])
  it_parses "def foo; x { |a| a }; end", Def.new('foo', [], [Call.new(nil, "x", [], Block.new(['a'.var], ['a'.var]))])

  it_parses "def foo(var = 1); end", Def.new("foo", [Arg.new("var", 1.int)], nil)
  it_parses "def foo var = 1; end", Def.new("foo", [Arg.new("var", 1.int)], nil)
  it_parses "def foo(var : Int); end", Def.new("foo", [Arg.new("var", nil, 'Int'.ident)], nil)
  it_parses "def foo var : Int; end", Def.new("foo", [Arg.new("var", nil, 'Int'.ident)], nil)
  it_parses "def foo(var : self); end", Def.new("foo", [Arg.new("var", nil, :self)], nil)
  it_parses "def foo var : self; end", Def.new("foo", [Arg.new("var", nil, :self)], nil)
  it_parses "def foo; yield; end", Def.new("foo", [], [Yield.new], nil, true)

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call(1.int)
  it_parses "foo 1", "foo".call(1.int)
  it_parses "foo 1\n", "foo".call(1.int)
  it_parses "foo 1;", "foo".call(1.int)
  it_parses "foo 1, 2", "foo".call(1.int, 2.int)
  it_parses "foo (1 + 2), 3", "foo".call(Call.new(1.int, :"+", [2.int]), 3.int)
  it_parses "foo(1 + 2)", "foo".call(Call.new(1.int, :"+", [2.int]))
  it_parses "foo -1.0, -2.0", "foo".call(-1.double, -2.double)
  it_parses "foo(\n1)", "foo".call(1.int)

  it_parses "foo + 1", Call.new("foo".call, :"+", [1.int])
  it_parses "foo +1", Call.new(nil, "foo", [1.int])
  it_parses "foo +1.0", Call.new(nil, "foo", [1.double])
  it_parses "foo +1L", Call.new(nil, "foo", [1.long])
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int), Call.new("foo".var, :+, [1.int])]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int), Call.new("foo".var, :-, [1.int])]

  it_parses "foo !false", Call.new(nil, "foo", [Call.new(false.bool, :'!@')])

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".ident, "new")])
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".ident, "new")])
  it_parses "f.x = - 1", Call.new("f".call, "x=", [Call.new(1.int, :'-@')])

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>].each do |op|
    it_parses "f.x #{op}= 2", Call.new("f".call, "x=", [Call.new(Call.new("f".call, "x"), op, [2.int])])
  end

  ["=", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "%", "&", "|", "^", "**", "+@", "-@", "~@", "!@", "||", "&&", '==='].each do |op|
    it_parses "def #{op}; end;", Def.new(op.to_sym, [], nil)
  end

  ['<<', '<', '<=', '==', '>>', '>', '>=', '+', '-', '*', '/', '%', '|', '&', '^', '**', '||', '&&', '==='].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int, op.to_sym, [2.int])
    it_parses "n #{op} 2", Call.new("n".call, op.to_sym, [2.int])
  end

  ['bar', :'+', :'-', :'*', :'/', :'<', :'<=', :'==', :'>', :'>=', :'%', :'|', :'&', :'^', :'**', :'||', :'&&', :'==='].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, [1.int, 2.int])
  end

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>, :'||', :'&&'].each do |op|
    it_parses "a = 1; a #{op}= 1", [Assign.new("a".var, 1.int), Assign.new("a".var, Call.new("a".var, op.to_sym, [1.int]))]
  end

  it_parses "if foo; 1; end", If.new("foo".call, 1.int)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int, 2.int)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int, 2.int)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int, If.new("bar".call, 2.int, 3.int))

  it_parses "include Foo", Include.new("Foo".ident)

  it_parses "unless foo; 1; end", If.new("foo".call.not, 1.int)
  it_parses "unless foo; 1; else; 2; end", If.new("foo".call.not, 1.int, 2.int)

  it_parses "class Foo; end", ClassDef.new("Foo")
  it_parses "class Foo\nend", ClassDef.new("Foo")
  it_parses "class Foo\ndef foo; end; end", ClassDef.new("Foo", [Def.new("foo", [], nil)])
  it_parses "class Foo < Bar; end", ClassDef.new("Foo", nil, "Bar".ident)
  it_parses "generic class Foo; end", ClassDef.new("Foo", nil, nil, true)

  it_parses "module Foo; end", ModuleDef.new("Foo")
  it_parses "module Foo\ndef foo; end; end", ModuleDef.new("Foo", [Def.new("foo", [], nil)])

  it_parses "while true; 1; end;", While.new(true.bool, 1.int)

  it_parses "foo do; 1; end", Call.new(nil, "foo", [], Block.new([], 1.int))
  it_parses "foo do |a|; 1; end", Call.new(nil, "foo", [], Block.new(["a".var], 1.int))

  it_parses "foo { 1 }", Call.new(nil, "foo", [], Block.new([], 1.int))
  it_parses "foo { |a| 1 }", Call.new(nil, "foo", [], Block.new(["a".var], 1.int))
  it_parses "foo { |a, b| 1 }", Call.new(nil, "foo", [], Block.new(["a".var, "b".var], 1.int))
  it_parses "1.foo do; 1; end", Call.new(1.int, "foo", [], Block.new([], 1.int))

  it_parses "1 ? 2 : 3", If.new(1.int, 2.int, 3.int)
  it_parses "1 ? a : b", If.new(1.int, "a".call, "b".call)

  it_parses "1 if 3", If.new(3.int, 1.int)
  it_parses "1 unless 3", If.new(3.int.not, 1.int)
  it_parses "1 while 3", While.new(3.int, 1.int, true)
  it_parses "a = 1; a += 10 if a += 20", [Assign.new("a".var, 1.int), If.new(Assign.new("a".var, Call.new("a".var, :+, [20.int])), Assign.new("a".var, Call.new("a".var, :+, [10.int])))]
  it_parses "puts a if true", If.new(true.bool, Call.new(nil, 'puts', ["a".call]))
  it_parses "puts a unless true", If.new(true.bool.not, Call.new(nil, 'puts', ["a".call]))
  it_parses "puts a while true", While.new(true.bool, Call.new(nil, 'puts', ["a".call]), true)

  ['return', 'next', 'break', 'yield'].each do |keyword|
    it_parses "#{keyword}", eval(keyword.capitalize).new
    it_parses "#{keyword};", eval(keyword.capitalize).new
    it_parses "#{keyword} 1", eval(keyword.capitalize).new([1.int])
    it_parses "#{keyword} 1 if true", If.new(true.bool, eval(keyword.capitalize).new([1.int]))
    it_parses "#{keyword} if true", If.new(true.bool, eval(keyword.capitalize).new)
  end

  it_parses "Int", "Int".ident

  it_parses "Int[]", Call.new("Int".ident, :[])
  it_parses "def []; end", Def.new(:[], [], nil)
  it_parses "def []=(value); end", Def.new(:[]=, ["value".arg], nil)
  it_parses "def self.[]; end", Def.new(:[], [], nil, "self".var)

  it_parses "Int[8]", Call.new("Int".ident, :[], [8.int])
  it_parses "Int[8, 4]", Call.new("Int".ident, :[], [8.int, 4.int])
  it_parses "Int[8, 4,]", Call.new("Int".ident, :[], [8.int, 4.int])

  it_parses "def [](x); end", Def.new(:[], ["x".arg], nil)

  it_parses "foo[0] = 1", Call.new("foo".call, :[]=, [0.int, 1.int])

  it_parses "begin; 1; 2; 3; end;", Expressions.new([1.int, 2.int, 3.int])

  it_parses "self", "self".var

  it_parses "@foo", "@foo".instance_var
  it_parses "@foo = 1", Assign.new("@foo".instance_var, 1.int)

  it_parses "call @foo.bar", Call.new(nil, "call", [Call.new("@foo".instance_var, "bar")])
  it_parses 'call "foo"', Call.new(nil, "call", ["foo".string])

  it_parses "def foo; end; if false; 1; else; 2; end", [Def.new('foo', []), If.new(false.bool, 1.int, 2.int)]

  it_parses %Q(A.new("x", B.new("y"))), Call.new("A".ident, "new", ["x".string, Call.new("B".ident, "new", ["y".string])])

  it_parses "foo []", Call.new(nil, "foo", [[].array])
  it_parses "foo [1]", Call.new(nil, "foo", [[1.int].array])
  it_parses "foo.bar []", Call.new("foo".call, "bar", [[].array])
  it_parses "foo.bar [1]", Call.new("foo".call, "bar", [[1.int].array])

  it_parses "class Foo; end\nwhile true; end", [ClassDef.new('Foo'), While.new(true.bool)]
  it_parses "while true; end\nif true; end", [While.new(true.bool), If.new(true.bool)]
  it_parses "(1)\nif true; end", [1.int, If.new(true.bool)]
  it_parses "begin\n1\nend\nif true; end", [1.int, If.new(true.bool)]

  it_parses "Foo::Bar", ['Foo', 'Bar'].ident

  it_parses "lib C\nend", LibDef.new('C')
  it_parses %Q(lib C("libc")\nend), LibDef.new('C', 'libc')
  it_parses "lib C\nfun getchar\nend", LibDef.new('C', nil, [FunDef.new('getchar')])
  it_parses "lib C\nfun getchar : Int\nend", LibDef.new('C', nil, [FunDef.new('getchar', [], 'Int'.ident)])
  it_parses "lib C\nfun getchar(a : Int, b : Float)\nend", LibDef.new('C', nil, [FunDef.new('getchar', [FunDefArg.new('a', 'Int'.ident), FunDefArg.new('b', 'Float'.ident)])])
  it_parses "lib C\nfun getchar(a : out Int)\nend", LibDef.new('C', nil, [FunDef.new('getchar', [FunDefArg.new('a', 'Int'.ident, 0, true)])])
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
  it_parses "lib C; Foo = 1; end", LibDef.new('C', nil, [Assign.new("Foo".ident, 1.int)])
  it_parses "lib C\nfun getch = GetChar\nend", LibDef.new('C', nil, [FunDef.new('getch', [], nil, 0, 'GetChar')])

  it_parses "1 .. 2", RangeLiteral.new(1.int, 2.int, false)
  it_parses "1 ... 2", RangeLiteral.new(1.int, 2.int, true)

  it_parses "A = 1", Assign.new("A".ident, 1.int)

  it_parses "puts %w(one)", Call.new(nil, 'puts', [['one'.string].array])

  it_parses "::A::B", Ident.new(['A', 'B'], true)

  it_parses "$foo", Global.new('$foo')

  it_parses "macro foo;end", Macro.new('foo', [])

  it_parses "a = 1; a.ptr", [Assign.new("a".var, 1.int), PointerOf.new('a'.var)]
  it_parses "@a.ptr", PointerOf.new('@a'.instance_var)

  it_parses "foo.is_a?(Const)", IsA.new("foo".call, "Const".ident)

  it_parses "/foo/", RegexpLiteral.new("foo")

  it_parses "1 =~ 2", Call.new(1.int, :=~, [2.int])
  it_parses "1.=~(2)", Call.new(1.int, :=~, [2.int])
  it_parses "def =~; end", Def.new(:=~, [])

  it_parses "foo $a", Call.new(nil, 'foo', [Global.new('$a')])

  it_parses "$1", Call.new(Global.new('$~'), :[], [1.int])
  it_parses "foo $1", Call.new(nil, 'foo', [Call.new(Global.new('$~'), :[], [1.int])])
  it_parses "foo /a/", Call.new(nil, 'foo', [RegexpLiteral.new('a')])

  it_parses "foo out x; x", [Call.new(nil, 'foo', [Var.new('x').tap { |v| v.out = true }]), Var.new('x')]
  it_parses "foo(out x); x", [Call.new(nil, 'foo', [Var.new('x').tap { |v| v.out = true }]), Var.new('x')]

  it_parses "{1 => 2, 3 => 4}", HashLiteral.new([1.int, 2.int, 3.int, 4.int])
  it_parses "{a: 1, b: 2}", HashLiteral.new(['a'.symbol, 1.int, 'b'.symbol, 2.int])
  it_parses "{a: 1, 3 => 4, b: 2}", HashLiteral.new(['a'.symbol, 1.int, 3.int, 4.int, 'b'.symbol, 2.int])

  it_parses %q(require "foo"), Require.new('foo'.string)
  it_parses %q(require "foo"; []), [Require.new('foo'.string), [].array]
  it_parses %Q(require "foo"\nif true; end), [Require.new('foo'.string), If.new(true.bool)]

  it_parses %q(case 1; when 1; 2; else; 3; end), Case.new(1.int, [When.new([1.int], 2.int)], 3.int)
  it_parses %q(case 1; when 0, 1; 2; else; 3; end), Case.new(1.int, [When.new([0.int, 1.int], 2.int)], 3.int)
  it_parses %Q(case 1\nwhen 1\n2\nelse\n3\nend), Case.new(1.int, [When.new([1.int], 2.int)], 3.int)
  it_parses %Q(case 1\nwhen 1\n2\nend), Case.new(1.int, [When.new([1.int], 2.int)])
end
