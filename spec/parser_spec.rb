require(File.expand_path("../../lib/crystal",  __FILE__))
include Crystal

describe Parser do
  def self.it_parses(string, expected_nodes, options = {})
    it "parses #{string}", options do
      node = Parser.parse(string)
      node.should eq(Expressions.new expected_nodes)
    end
  end

  def self.it_parses_single_node(string, expected_node, options = {})
    it_parses string, [expected_node], options
  end

  it_parses_single_node "1", 1.int
  it_parses_single_node "+1", 1.int
  it_parses_single_node "-1", -1.int
  it_parses_single_node "1.0", 1.0.float
  it_parses_single_node "+1.0", 1.0.float
  it_parses_single_node "-1.0", -1.0.float
  it_parses_single_node "1 + 2", Call.new(1.int, :"+", [2.int])
  it_parses_single_node "1 +\n2", Call.new(1.int, :"+", [2.int])
  it_parses_single_node "1 +2", Call.new(1.int, :"+", [2.int])
  it_parses_single_node "1 -2", Call.new(1.int, :"-", [-2.int])
  it_parses "1\n+2", [1.int, 2.int]
  it_parses "1;+2", [1.int, 2.int]
  it_parses_single_node "1 - 2", Call.new(1.int, :"-", [2.int])
  it_parses_single_node "1 -\n2", Call.new(1.int, :"-", [2.int])
  it_parses "1\n-2", [1.int, -2.int]
  it_parses "1;-2", [1.int, -2.int]
  it_parses_single_node "1 * 2", Call.new(1.int, :"*", [2.int])
  it_parses_single_node "1 * -2", Call.new(1.int, :"*", [-2.int])
  it_parses_single_node "2 * 3 + 4 * 5", Call.new(Call.new(2.int, :"*", [3.int]), :"+", [Call.new(4.int, :"*", [5.int])])
  it_parses_single_node "1 / 2", Call.new(1.int, :"/", [2.int])
  it_parses_single_node "1 / -2", Call.new(1.int, :"/", [-2.int])
  it_parses_single_node "2 / 3 + 4 / 5", Call.new(Call.new(2.int, :"/", [3.int]), :"+", [Call.new(4.int, :"/", [5.int])])

  it_parses_single_node "(1)", 1.int
  it_parses_single_node "2 * (3 + 4)", Call.new(2.int, :"*", [Call.new(3.int, :"+", [4.int])])

  it_parses_single_node "def foo\n1\nend", Def.new("foo", [], [1.int])
  it_parses_single_node "def downto(n)\n1\nend", Def.new("downto", ["n".var], [1.int])
  it_parses_single_node "def foo ; 1 ; end", Def.new("foo", [], [1.int])
  it_parses_single_node "def foo; end", Def.new("foo", [], nil)
  it_parses_single_node "def foo(var); end", Def.new("foo", ["var".var], nil)
  it_parses_single_node "def foo(\nvar); end", Def.new("foo", ["var".var], nil)
  it_parses_single_node "def foo(\nvar\n); end", Def.new("foo", ["var".var], nil)
  it_parses_single_node "def foo(var1, var2); end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses_single_node "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses_single_node "def foo var; end", Def.new("foo", ["var".var], nil)
  it_parses_single_node "def foo var\n end", Def.new("foo", ["var".var], nil)
  it_parses_single_node "def foo var1, var2\n end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses_single_node "def foo var1,\nvar2\n end", Def.new("foo", ["var1".var, "var2".var], nil)
  it_parses_single_node "def foo; 1; 2; end", Def.new("foo", [], [1.int, 2.int])
  it_parses_single_node "def foo(n); foo(n -1); end", Def.new("foo", ["n".var], Call.new(nil, "foo", [Call.new(nil, "n", [-1.int])]))

  it_parses_single_node "def self.foo\n1\nend", Def.new("foo", [], [1.int], "self".ref)

  it_parses_single_node "foo", "foo".ref
  it_parses_single_node "foo()", Call.new(nil, "foo", [])
  it_parses_single_node "foo(1)", Call.new(nil, "foo", [1.int])
  it_parses_single_node "foo 1", Call.new(nil, "foo", [1.int])
  it_parses_single_node "foo 1\n", Call.new(nil, "foo", [1.int])
  it_parses_single_node "foo 1;", Call.new(nil, "foo", [1.int])
  it_parses_single_node "foo 1, 2", Call.new(nil, "foo", [1.int, 2.int])
  it_parses_single_node "foo (1 + 2), 3", Call.new(nil, "foo", [Call.new(1.int, :"+", [2.int]), 3.int])
  it_parses_single_node "foo(1 + 2)", Call.new(nil, "foo", [Call.new(1.int, :"+", [2.int])])
  it_parses_single_node "foo -1.0, -2.0", Call.new(nil, "foo", [-1.float, -2.float])

  it_parses_single_node "foo + 1", Call.new("foo".ref, :"+", [1.int])
  it_parses_single_node "foo +1", Call.new(nil, "foo", [1.int])

  it_parses_single_node "foo !false", Call.new(nil, "foo", [Not.new(false.bool)])

  ["=", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "%", "&", "|", "^", "**", "+@", "-@"].each do |op|
    it_parses_single_node "def #{op}; end;", Def.new(op.to_sym, [], nil)
  end

  ['<<', '<', '<=', '==', '>>', '>', '>=', '+', '-', '*', '/', '%', '|', '&', '^', '**'].each do |op|
    it_parses_single_node "1 #{op} 2", Call.new(1.int, op.to_sym, [2.int])
    it_parses_single_node "n #{op} 2", Call.new("n".ref, op.to_sym, [2.int])
  end

  ['bar', :'+', :'-', :'*', :'/', :'<', :'<=', :'==', :'>', :'>=', :'%', :'|', :'&', :'^', :'**'].each do |name|
    it_parses_single_node "foo.#{name}", Call.new("foo".ref, name)
    it_parses_single_node "foo.#{name} 1, 2", Call.new("foo".ref, name, [1.int, 2.int])
  end

  [:'+', :'-', :'*', :'/', :'%', :'|', :'&', :'^', :'**', :<<, :>>].each do |op|
    it_parses_single_node "a #{op}= 1", Assign.new("a".ref, Call.new("a".ref, op.to_sym, [1.int]))
  end

  it_parses_single_node "if foo; 1; end", If.new("foo".ref, 1.int)
  it_parses_single_node "if foo\n1\nend", If.new("foo".ref, 1.int)
  it_parses_single_node "if foo; 1; else; 2; end", If.new("foo".ref, 1.int, 2.int)
  it_parses_single_node "if foo\n1\nelse\n2\nend", If.new("foo".ref, 1.int, 2.int)
  it_parses_single_node "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".ref, 1.int, If.new("bar".ref, 2.int, 3.int))

  it_parses_single_node "unless foo; 1; end", If.new("foo".ref, nil, 1.int)
  it_parses_single_node "unless foo; 1; else; 2; end", If.new("foo".ref, 2.int, 1.int)

  it_parses_single_node "foo.bar.baz", Call.new(Call.new("foo".ref, "bar"), "baz")
  it_parses_single_node "-x", Call.new("x".ref, :"-@")
  it_parses_single_node "+x", Call.new("x".ref, :"+@")
  it_parses_single_node "+ 1", Call.new(1.int, :"+@")

  it_parses_single_node "true", true.bool
  it_parses_single_node "false", false.bool

  it_parses_single_node "class Foo; end", ClassDef.new("Foo")
  it_parses_single_node "class Foo\nend", ClassDef.new("Foo")
  it_parses_single_node "class Foo\ndef foo; end; end", ClassDef.new("Foo", [Def.new("foo", [], nil)])
  it_parses_single_node "class Foo < Bar; end", ClassDef.new("Foo", nil, "Bar")

  it_parses_single_node "a = 1", Assign.new("a".ref, 1.int)

  it_parses_single_node "while true; 1; end;", While.new(true.bool, 1.int)

  it_parses_single_node "nil", Nil.new

  it_parses_single_node "!1", Not.new(1.int)
  it_parses_single_node "1 && 2", And.new(1.int, 2.int)
  it_parses_single_node "1 || 2", Or.new(1.int, 2.int)

  it_parses_single_node "'a'", Char.new(?a.ord)

  it_parses_single_node "foo do; 1; end", Call.new(nil, "foo", [], Block.new([], 1.int))
  it_parses_single_node "foo do |a|; 1; end", Call.new(nil, "foo", [], Block.new(["a".var], 1.int))
  it_parses_single_node "foo do |a, b|; 1; end", Call.new(nil, "foo", [], Block.new(["a".var, "b".var], 1.int))
  it_parses_single_node "foo { 1 }", Call.new(nil, "foo", [], Block.new([], 1.int))
  it_parses_single_node "foo { |a| 1 }", Call.new(nil, "foo", [], Block.new(["a".var], 1.int))
  it_parses_single_node "foo { |a, b| 1 }", Call.new(nil, "foo", [], Block.new(["a".var, "b".var], 1.int))
  it_parses_single_node "1.foo do; 1; end", Call.new(1.int, "foo", [], Block.new([], 1.int))

  it_parses_single_node "yield 1", Yield.new([1.int])
  it_parses_single_node "1 ? 2 : 3", If.new(1.int, 2.int, 3.int)
  it_parses_single_node "1 ? a : b", If.new(1.int, "a".ref, "b".ref)

  it_parses_single_node "return", Return.new
  it_parses_single_node "return;", Return.new
  it_parses_single_node "return 1", Return.new(1.int)

  it_parses_single_node "next", Next.new
  it_parses_single_node "next;", Next.new
  it_parses_single_node "next 1", Next.new(1.int)

  it_parses_single_node "break", Break.new
  it_parses_single_node "break;", Break.new
  it_parses_single_node "break 1", Break.new(1.int)

  it_parses_single_node "1 if 3", If.new(3.int, 1.int)
  it_parses_single_node "1 unless 3", If.new(3.int, nil, 1.int)
  it_parses_single_node "1 while 3", While.new(3.int, 1.int)
  it_parses_single_node "a += 10 if a += 20", If.new(Assign.new("a".ref, Call.new("a".ref, :+, [20.int])), Assign.new("a".ref, Call.new("a".ref, :+, [10.int])))
  it_parses_single_node "puts a if true", If.new(true.bool, Call.new(nil, 'puts', ["a".ref]))
  it_parses_single_node "puts a unless true", If.new(true.bool, nil, Call.new(nil, 'puts', ["a".ref]))
  it_parses_single_node "puts a while true", While.new(true.bool, Call.new(nil, 'puts', ["a".ref]))
  it_parses_single_node "next 1 if true", If.new(true.bool, Next.new(1.int))
  it_parses_single_node "next if true", If.new(true.bool, Next.new)
  it_parses_single_node "return 1 if true", If.new(true.bool, Return.new(1.int))
  it_parses_single_node "return if true", If.new(true.bool, Return.new)
  it_parses_single_node "break 1 if true", If.new(true.bool, Break.new(1.int))
  it_parses_single_node "break if true", If.new(true.bool, Break.new)

  it_parses_single_node "Int[]", Call.new("Int".ref, :[])
  it_parses_single_node "def []; end", Def.new(:[], [], nil)
  it_parses_single_node "def self.[]; end", Def.new(:[], [], nil, "self".ref)

  it_parses_single_node "Int[8]", Call.new("Int".ref, :'[ ]', [8.int])
  it_parses_single_node "Int[8, 4]", Call.new("Int".ref, :'[ ]', [8.int, 4.int])
  it_parses_single_node "Int[8, 4,]", Call.new("Int".ref, :'[ ]', [8.int, 4.int])

  it_parses_single_node "def [](x); end", Def.new(:'[ ]', ["x".var], nil)

  it_parses_single_node "foo[0] = 1", Call.new("foo".ref, :[]=, [0.int, 1.int])

  it_parses_single_node "begin; 1; 2; 3; end;", Expressions.new([1.int, 2.int, 3.int])
end
