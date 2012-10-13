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

  it_parses "1.0", 1.0.float
  it_parses "+1.0", 1.0.float
  it_parses "-1.0", -1.0.float

  it_parses "'a'", CharLiteral.new(?a.ord)

  it_parses %("foo"), StringLiteral.new("foo")

  it_parses "[]", [].array
  it_parses "[1, 2]", [1.int, 2.int].array
  it_parses "[\n1, 2]", [1.int, 2.int].array
  it_parses "[1,\n 2,]", [1.int, 2.int].array

  it_parses "-x", Call.new("x".call, :"-@")
  it_parses "+x", Call.new("x".call, :"+@")
  it_parses "+ 1", Call.new(1.int, :"+@")

  it_parses "1 + 2", Call.new(1.int, :"+", [2.int])
  it_parses "1 +\n2", Call.new(1.int, :"+", [2.int])
  it_parses "1 +2", Call.new(1.int, :"+", [2.int])
  it_parses "1 -2", Call.new(1.int, :"-", [2.int])
  it_parses "1 +2.0", Call.new(1.int, :"+", [2.float])
  it_parses "1 -2.0", Call.new(1.int, :"-", [2.float])
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

  it_parses "a = 1", Assign.new("a".var, 1.int)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int))

  it_parses "def foo\n1\nend", Def.new("foo", [], [1.int])
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".var], [1.int])
  it_parses "def foo ; 1 ; end", Def.new("foo", [], [1.int])
  it_parses "def foo; end", Def.new("foo", [], nil)
  it_parses "def foo(var); end", Def.new("foo", ["var".var], nil)
  it_parses "def foo(\nvar); end", Def.new("foo", ["var".var], nil)
  it_parses "def foo(\nvar\n); end", Def.new("foo", ["var".var], nil)
  it_parses "def foo(var1, var2); end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses "def foo var; end", Def.new("foo", ["var".var], nil)
  it_parses "def foo var\n end", Def.new("foo", ["var".var], nil)
  it_parses "def foo var1, var2\n end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses "def foo var1,\nvar2\n end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses "def foo; 1; 2; end", Def.new("foo", [], [1.int, 2.int])
  it_parses "def foo=(value); end", Def.new("foo=", ["value".var], [])
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".var], "foo".call(Call.new("n".var, :-, [1.int])))

  it_parses "def self.foo\n1\nend", Def.new("foo", [], [1.int], "self".var)

  it_parses "def foo; a; end", Def.new('foo', [], ["a".call])
  it_parses "def foo(a); a; end", Def.new('foo', ['a'.var], ["a".var])
  it_parses "def foo; a = 1; a; end", Def.new('foo', [], [Assign.new('a'.var, 1.int), 'a'.var])
  it_parses "def foo; a = 1; a {}; end", Def.new('foo', [], [Assign.new('a'.var, 1.int), Call.new(nil, "a", [], Block.new)])
  it_parses "def foo; a = 1; x { a }; end", Def.new('foo', [], [Assign.new('a'.var, 1.int), Call.new(nil, "x", [], Block.new([], ['a'.var]))])
  it_parses "def foo; x { |a| a }; end", Def.new('foo', [], [Call.new(nil, "x", [], Block.new(['a'.var], ['a'.var]))])

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call(1.int)
  it_parses "foo 1", "foo".call(1.int)
  it_parses "foo 1\n", "foo".call(1.int)
  it_parses "foo 1;", "foo".call(1.int)
  it_parses "foo 1, 2", "foo".call(1.int, 2.int)
  it_parses "foo (1 + 2), 3", "foo".call(Call.new(1.int, :"+", [2.int]), 3.int)
  it_parses "foo(1 + 2)", "foo".call(Call.new(1.int, :"+", [2.int]))
  it_parses "foo -1.0, -2.0", "foo".call(-1.float, -2.float)

  it_parses "foo + 1", Call.new("foo".call, :"+", [1.int])
  it_parses "foo +1", Call.new(nil, "foo", [1.int])
  it_parses "foo +1.0", Call.new(nil, "foo", [1.float])
  it_parses "foo +1L", Call.new(nil, "foo", [1.long])
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int), Call.new("foo".var, :+, [1.int])]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int), Call.new("foo".var, :-, [1.int])]

  it_parses "foo !false", Call.new(nil, "foo", [Call.new(false.bool, :'!@')])

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".const, "new")])
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".const, "new")])

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>].each do |op|
    it_parses "f.x #{op}= 2", Call.new("f".call, "x=", [Call.new(Call.new("f".call, "x"), op, [2.int])])
  end

  ["=", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "%", "&", "|", "^", "**", "+@", "-@"].each do |op|
    it_parses "def #{op}; end;", Def.new(op.to_sym, [], nil)
  end

  ['<<', '<', '<=', '==', '>>', '>', '>=', '+', '-', '*', '/', '%', '|', '&', '^', '**'].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int, op.to_sym, [2.int])
    it_parses "n #{op} 2", Call.new("n".call, op.to_sym, [2.int])
  end

  ['bar', :'+', :'-', :'*', :'/', :'<', :'<=', :'==', :'>', :'>=', :'%', :'|', :'&', :'^', :'**'].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, [1.int, 2.int])
  end

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>].each do |op|
    it_parses "a #{op}= 1", Assign.new("a".var, Call.new("a".var, op.to_sym, [1.int]))
  end

  it_parses "if foo; 1; end", If.new("foo".call, 1.int)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int, 2.int)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int, 2.int)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int, If.new("bar".call, 2.int, 3.int))

  it_parses "unless foo; 1; end", If.new("foo".call.not, 1.int)
  it_parses "unless foo; 1; else; 2; end", If.new("foo".call.not, 1.int, 2.int)

  it_parses "class Foo; end", ClassDef.new("Foo")
  it_parses "class Foo\nend", ClassDef.new("Foo")
  it_parses "class Foo\ndef foo; end; end", ClassDef.new("Foo", [Def.new("foo", [], nil)])
  it_parses "class Foo < Bar; end", ClassDef.new("Foo", nil, "Bar")

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
  it_parses "1 while 3", While.new(3.int, 1.int)
  it_parses "a += 10 if a += 20", If.new(Assign.new("a".var, Call.new("a".var, :+, [20.int])), Assign.new("a".var, Call.new("a".var, :+, [10.int])))
  it_parses "puts a if true", If.new(true.bool, Call.new(nil, 'puts', ["a".call]))
  it_parses "puts a unless true", If.new(true.bool.not, Call.new(nil, 'puts', ["a".call]))
  it_parses "puts a while true", While.new(true.bool, Call.new(nil, 'puts', ["a".call]))

  ['return', 'next', 'break', 'yield'].each do |keyword|
    it_parses "#{keyword}", eval(keyword.capitalize).new
    it_parses "#{keyword};", eval(keyword.capitalize).new
    it_parses "#{keyword} 1", eval(keyword.capitalize).new([1.int])
    it_parses "#{keyword} 1 if true", If.new(true.bool, eval(keyword.capitalize).new([1.int]))
    it_parses "#{keyword} if true", If.new(true.bool, eval(keyword.capitalize).new)
  end

  it_parses "Int", "Int".const

  it_parses "Int[]", Call.new("Int".const, :[])
  it_parses "def []; end", Def.new(:[], [], nil)
  it_parses "def []=(value); end", Def.new(:[]=, ["value".var], nil)
  it_parses "def self.[]; end", Def.new(:[], [], nil, "self".var)

  it_parses "Int[8]", Call.new("Int".const, :[], [8.int])
  it_parses "Int[8, 4]", Call.new("Int".const, :[], [8.int, 4.int])
  it_parses "Int[8, 4,]", Call.new("Int".const, :[], [8.int, 4.int])

  it_parses "def [](x); end", Def.new(:[], ["x".var], nil)

  it_parses "foo[0] = 1", Call.new("foo".call, :[]=, [0.int, 1.int])

  it_parses "begin; 1; 2; 3; end;", Expressions.new([1.int, 2.int, 3.int])

  it_parses "self", "self".var

  it_parses "@foo", "@foo".instance_var
  it_parses "@foo = 1", Assign.new("@foo".instance_var, 1.int)

  it_parses "call @foo.bar", Call.new(nil, "call", [Call.new("@foo".instance_var, "bar")])
  it_parses 'call "foo"', Call.new(nil, "call", ["foo".string])

  it_parses "def foo; end; if false; 1; else; 2; end", [Def.new('foo', []), If.new(false.bool, 1.int, 2.int)]
end
