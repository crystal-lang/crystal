require "../../support/syntax"

private def regex(string, options = Regex::Options::None)
  RegexLiteral.new(StringLiteral.new(string), options)
end

private def it_parses(string, expected_node, file = __FILE__, line = __LINE__)
  it "parses #{string}", file, line do
    parser = Parser.new(string)
    parser.filename = "/foo/bar/baz.cr"
    node = parser.parse
    node.should eq(Expressions.from expected_node)
  end
end

private def assert_end_location(source, line_number = 1, column_number = source.size, file = __FILE__, line = __LINE__)
  it "gets corrects end location for #{source.inspect}", file, line do
    parser = Parser.new("#{source}; 1")
    node = parser.parse.as(Expressions).expressions[0]
    end_loc = node.end_location.not_nil!
    end_loc.line_number.should eq(line_number)
    end_loc.column_number.should eq(column_number)
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

  it_parses "1_u128", 1.uint128
  it_parses "1_i128", 1.int128

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
  it_parses %("hello \\\n     world"), "hello world".string

  it_parses %(%Q{hello \\n world}), "hello \n world".string
  it_parses %(%q{hello \\n world}), "hello \\n world".string
  it_parses %(%q{hello \#{foo} world}), "hello \#{foo} world".string

  [":foo", ":foo!", ":foo?", ":\"foo\"", ":かたな", ":+", ":-", ":*", ":/", ":==", ":<", ":<=", ":>",
   ":>=", ":!", ":!=", ":=~", ":!~", ":&", ":|", ":^", ":~", ":**", ":>>", ":<<", ":%", ":[]", ":[]?",
   ":[]=", ":<=>", ":==="].each do |symbol|
    value = symbol[1, symbol.size - 1]
    value = value[1, value.size - 2] if value.starts_with?("\"")
    it_parses symbol, value.symbol
  end
  it_parses ":foo", "foo".symbol
  it_parses ":[]=", "[]=".symbol
  it_parses ":[]?", "[]?".symbol
  it_parses %(:"\\\\foo"), "\\foo".symbol
  it_parses %(:"\\\"foo"), "\"foo".symbol
  it_parses %(:"\\\"foo\\\""), "\"foo\"".symbol
  it_parses %(:"\\b\\n\\r\\t\\v\\f\\e"), "\b\n\r\t\v\f\e".symbol
  it_parses %(:"\\u{61}"), "a".symbol

  it_parses "[1, 2]", ([1.int32, 2.int32] of ASTNode).array
  it_parses "[\n1, 2]", ([1.int32, 2.int32] of ASTNode).array
  it_parses "[1,\n 2,]", ([1.int32, 2.int32] of ASTNode).array

  it_parses "1 + 2", Call.new(1.int32, "+", 2.int32)
  it_parses "1 +\n2", Call.new(1.int32, "+", 2.int32)
  it_parses "1 +2", Call.new(1.int32, "+", 2.int32)
  it_parses "1 -2", Call.new(1.int32, "-", 2.int32)
  it_parses "1 +2.0", Call.new(1.int32, "+", 2.float64)
  it_parses "1 -2.0", Call.new(1.int32, "-", 2.float64)
  it_parses "1 +2_i64", Call.new(1.int32, "+", 2.int64)
  it_parses "1 -2_i64", Call.new(1.int32, "-", 2.int64)
  it_parses "1\n+2", [1.int32, 2.int32] of ASTNode
  it_parses "1;+2", [1.int32, 2.int32] of ASTNode
  it_parses "1 - 2", Call.new(1.int32, "-", 2.int32)
  it_parses "1 -\n2", Call.new(1.int32, "-", 2.int32)
  it_parses "1\n-2", [1.int32, -2.int32] of ASTNode
  it_parses "1;-2", [1.int32, -2.int32] of ASTNode
  it_parses "1 * 2", Call.new(1.int32, "*", 2.int32)
  it_parses "1 * -2", Call.new(1.int32, "*", -2.int32)
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int32, "*", 3.int32), "+", Call.new(4.int32, "*", 5.int32))
  it_parses "1 / 2", Call.new(1.int32, "/", 2.int32)
  it_parses "1 / -2", Call.new(1.int32, "/", -2.int32)
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int32, "/", 3.int32), "+", Call.new(4.int32, "/", 5.int32))
  it_parses "2 * (3 + 4)", Call.new(2.int32, "*", Expressions.new([Call.new(3.int32, "+", 4.int32)] of ASTNode))
  it_parses "1/2", Call.new(1.int32, "/", [2.int32] of ASTNode)
  it_parses "1 + /foo/", Call.new(1.int32, "+", regex("foo"))
  it_parses "1+0", Call.new(1.int32, "+", 0.int32)
  it_parses "a = 1; a /b", [Assign.new("a".var, 1.int32), Call.new("a".var, "/", "b".call)]
  it_parses "a = 1; a/b", [Assign.new("a".var, 1.int32), Call.new("a".var, "/", "b".call)]
  it_parses "a = 1; (a)/b", [Assign.new("a".var, 1.int32), Call.new(Expressions.new(["a".var] of ASTNode), "/", "b".call)]
  it_parses "_ = 1", Assign.new(Underscore.new, 1.int32)
  it_parses "@foo/2", Call.new("@foo".instance_var, "/", 2.int32)
  it_parses "@@foo/2", Call.new("@@foo".class_var, "/", 2.int32)
  it_parses "1+2*3", Call.new(1.int32, "+", Call.new(2.int32, "*", 3.int32))
  it_parses "foo[] /2", Call.new(Call.new("foo".call, "[]"), "/", 2.int32)
  it_parses "foo[1] /2", Call.new(Call.new("foo".call, "[]", 1.int32), "/", 2.int32)
  it_parses "[1] /2", Call.new(([1.int32] of ASTNode).array, "/", 2.int32)

  it_parses "!1", Not.new(1.int32)
  it_parses "- 1", Call.new(1.int32, "-")
  it_parses "+ 1", Call.new(1.int32, "+")
  it_parses "~ 1", Call.new(1.int32, "~")
  it_parses "1 && 2", And.new(1.int32, 2.int32)
  it_parses "1 || 2", Or.new(1.int32, 2.int32)

  it_parses "1 <=> 2", Call.new(1.int32, "<=>", 2.int32)
  it_parses "1 !~ 2", Call.new(1.int32, "!~", 2.int32)

  it_parses "a = 1", Assign.new("a".var, 1.int32)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int32))

  it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var] of ASTNode, [1.int32] of ASTNode)
  it_parses "_, _ = 1, 2", MultiAssign.new([Underscore.new, Underscore.new] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "a[0], a[1] = 1, 2", MultiAssign.new([Call.new("a".call, "[]", 0.int32), Call.new("a".call, "[]", 1.int32)] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "a.foo, a.bar = 1, 2", MultiAssign.new([Call.new("a".call, "foo"), Call.new("a".call, "bar")] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "x = 0; a, b = x += 1", [Assign.new("x".var, 0.int32), MultiAssign.new(["a".var, "b".var] of ASTNode, [OpAssign.new("x".var, "+", 1.int32)] of ASTNode)] of ASTNode
  it_parses "a, b = 1, 2 if 3", If.new(3.int32, MultiAssign.new(["a".var, "b".var] of ASTNode, [1.int32, 2.int32] of ASTNode))

  it_parses "@a, b = 1, 2", MultiAssign.new(["@a".instance_var, "b".var] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "@@a, b = 1, 2", MultiAssign.new(["@@a".class_var, "b".var] of ASTNode, [1.int32, 2.int32] of ASTNode)

  assert_syntax_error "1 == 2, a = 4"
  assert_syntax_error "x : String, a = 4"
  assert_syntax_error "b, 1 == 2, a = 4"
  assert_syntax_error "a = 1, 2, 3", "Multiple assignment count mismatch"
  assert_syntax_error "a = 1, b = 2", "Multiple assignment count mismatch"

  it_parses "def foo\n1\nend", Def.new("foo", body: 1.int32)
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".arg], 1.int32)
  it_parses "def foo ; 1 ; end", Def.new("foo", body: 1.int32)
  it_parses "def foo; end", Def.new("foo")
  it_parses "def foo(var); end", Def.new("foo", ["var".arg])
  it_parses "def foo(\nvar); end", Def.new("foo", ["var".arg])
  it_parses "def foo(\nvar\n); end", Def.new("foo", ["var".arg])
  it_parses "def foo(var1, var2); end", Def.new("foo", ["var1".arg, "var2".arg])
  it_parses "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".arg, "var2".arg])
  it_parses "def foo; 1; 2; end", Def.new("foo", body: [1.int32, 2.int32] of ASTNode)
  it_parses "def foo=(value); end", Def.new("foo=", ["value".arg])
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".arg], "foo".call(Call.new("n".var, "-", 1.int32)))
  it_parses "def type(type); end", Def.new("type", ["type".arg])

  # #4815
  assert_syntax_error "def foo!=; end", "unexpected token: !="
  assert_syntax_error "def foo?=(x); end", "unexpected token: ?"

  it_parses "def self.foo\n1\nend", Def.new("foo", body: 1.int32, receiver: "self".var)
  it_parses "def self.foo()\n1\nend", Def.new("foo", body: 1.int32, receiver: "self".var)
  it_parses "def self.foo=\n1\nend", Def.new("foo=", body: 1.int32, receiver: "self".var)
  it_parses "def self.foo=()\n1\nend", Def.new("foo=", body: 1.int32, receiver: "self".var)
  it_parses "def Foo.foo\n1\nend", Def.new("foo", body: 1.int32, receiver: "Foo".path)
  it_parses "def Foo::Bar.foo\n1\nend", Def.new("foo", body: 1.int32, receiver: ["Foo", "Bar"].path)

  it_parses "def foo; a; end", Def.new("foo", body: "a".call)
  it_parses "def foo(a); a; end", Def.new("foo", ["a".arg], "a".var)
  it_parses "def foo; a = 1; a; end", Def.new("foo", body: [Assign.new("a".var, 1.int32), "a".var] of ASTNode)
  it_parses "def foo; a = 1; a {}; end", Def.new("foo", body: [Assign.new("a".var, 1.int32), Call.new(nil, "a", block: Block.new)] of ASTNode)
  it_parses "def foo; a = 1; x { a }; end", Def.new("foo", body: [Assign.new("a".var, 1.int32), Call.new(nil, "x", block: Block.new(body: ["a".var] of ASTNode))] of ASTNode)
  it_parses "def foo; x { |a| a }; end", Def.new("foo", body: [Call.new(nil, "x", block: Block.new(["a".var], ["a".var] of ASTNode))] of ASTNode)
  it_parses "def foo; x { |_| 1 }; end", Def.new("foo", body: [Call.new(nil, "x", block: Block.new(["_".var], [1.int32] of ASTNode))] of ASTNode)
  it_parses "def foo; x { |a, *b| b }; end", Def.new("foo", body: [Call.new(nil, "x", block: Block.new(["a".var, "b".var], ["b".var] of ASTNode, splat_index: 1))] of ASTNode)
  assert_syntax_error "x { |*a, *b| }", "splat block argument already specified"

  it_parses "def foo(var = 1); end", Def.new("foo", [Arg.new("var", 1.int32)])
  it_parses "def foo(var : Int); end", Def.new("foo", [Arg.new("var", restriction: "Int".path)])
  it_parses "def foo(var : self); end", Def.new("foo", [Arg.new("var", restriction: Self.new)])
  it_parses "def foo(var : self?); end", Def.new("foo", [Arg.new("var", restriction: Crystal::Union.new([Self.new, Path.global("Nil")] of ASTNode))])
  it_parses "def foo(var : self.class); end", Def.new("foo", [Arg.new("var", restriction: Metaclass.new(Self.new))])
  it_parses "def foo(var : self*); end", Def.new("foo", [Arg.new("var", restriction: Self.new.pointer_of)])
  it_parses "def foo(var : Int | Double); end", Def.new("foo", [Arg.new("var", restriction: Crystal::Union.new(["Int".path, "Double".path] of ASTNode))])
  it_parses "def foo(var : Int?); end", Def.new("foo", [Arg.new("var", restriction: Crystal::Union.new(["Int".path, "Nil".path(true)] of ASTNode))])
  it_parses "def foo(var : Int*); end", Def.new("foo", [Arg.new("var", restriction: "Int".path.pointer_of)])
  it_parses "def foo(var : Int**); end", Def.new("foo", [Arg.new("var", restriction: "Int".path.pointer_of.pointer_of)])
  it_parses "def foo(var : Int -> Double); end", Def.new("foo", [Arg.new("var", restriction: ProcNotation.new(["Int".path] of ASTNode, "Double".path))])
  it_parses "def foo(var : Int, Float -> Double); end", Def.new("foo", [Arg.new("var", restriction: ProcNotation.new(["Int".path, "Float".path] of ASTNode, "Double".path))])
  it_parses "def foo(var : (Int, Float -> Double)); end", Def.new("foo", [Arg.new("var", restriction: ProcNotation.new(["Int".path, "Float".path] of ASTNode, "Double".path))])
  it_parses "def foo(var : (Int, Float) -> Double); end", Def.new("foo", [Arg.new("var", restriction: ProcNotation.new(["Int".path, "Float".path] of ASTNode, "Double".path))])
  it_parses "def foo(var : Char[256]); end", Def.new("foo", [Arg.new("var", restriction: "Char".static_array_of(256))])
  it_parses "def foo(var : Char[N]); end", Def.new("foo", [Arg.new("var", restriction: "Char".static_array_of("N".path))])
  it_parses "def foo(var : Int32 = 1); end", Def.new("foo", [Arg.new("var", 1.int32, "Int32".path)])
  it_parses "def foo(var : Int32 -> = 1); end", Def.new("foo", [Arg.new("var", 1.int32, ProcNotation.new(["Int32".path] of ASTNode))])
  it_parses "def foo; yield; end", Def.new("foo", body: Yield.new, yields: 0)
  it_parses "def foo; yield 1; end", Def.new("foo", body: Yield.new([1.int32] of ASTNode), yields: 1)
  it_parses "def foo; yield 1; yield; end", Def.new("foo", body: [Yield.new([1.int32] of ASTNode), Yield.new] of ASTNode, yields: 1)
  it_parses "def foo(a, b = a); end", Def.new("foo", [Arg.new("a"), Arg.new("b", "a".var)])
  it_parses "def foo(&block); end", Def.new("foo", block_arg: Arg.new("block"), yields: 0)
  it_parses "def foo(a, &block); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block"), yields: 0)
  it_parses "def foo(a, &block : Int -> Double); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new(["Int".path] of ASTNode, "Double".path)), yields: 1)
  it_parses "def foo(a, &block : Int, Float -> Double); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new(["Int".path, "Float".path] of ASTNode, "Double".path)), yields: 2)
  it_parses "def foo(a, &block : Int, self -> Double); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new(["Int".path, Self.new] of ASTNode, "Double".path)), yields: 2)
  it_parses "def foo(a, &block : -> Double); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new(nil, "Double".path)), yields: 0)
  it_parses "def foo(a, &block : Int -> ); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new(["Int".path] of ASTNode)), yields: 1)
  it_parses "def foo(a, &block : self -> self); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new([Self.new] of ASTNode, Self.new)), yields: 1)
  it_parses "def foo(a, &block : Foo); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: Path.new("Foo")), yields: 0)
  it_parses "def foo; with a yield; end", Def.new("foo", body: Yield.new(scope: "a".call), yields: 1)
  it_parses "def foo; with a yield 1; end", Def.new("foo", body: Yield.new([1.int32] of ASTNode, "a".call), yields: 1)
  it_parses "def foo; a = 1; with a yield a; end", Def.new("foo", body: [Assign.new("a".var, 1.int32), Yield.new(["a".var] of ASTNode, "a".var)] of ASTNode, yields: 1)
  it_parses "def foo(@var); end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var)] of ASTNode)
  it_parses "def foo(@var); 1; end", Def.new("foo", [Arg.new("var")], [Assign.new("@var".instance_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(@var = 1); 1; end", Def.new("foo", [Arg.new("var", 1.int32)], [Assign.new("@var".instance_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(@@var); end", Def.new("foo", [Arg.new("var")], [Assign.new("@@var".class_var, "var".var)] of ASTNode)
  it_parses "def foo(@@var); 1; end", Def.new("foo", [Arg.new("var")], [Assign.new("@@var".class_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(@@var = 1); 1; end", Def.new("foo", [Arg.new("var", 1.int32)], [Assign.new("@@var".class_var, "var".var), 1.int32] of ASTNode)
  it_parses "def foo(&@block); end", Def.new("foo", body: Assign.new("@block".instance_var, "block".var), block_arg: Arg.new("block"), yields: 0)

  it_parses "def foo(a, &block : *Int -> ); end", Def.new("foo", [Arg.new("a")], block_arg: Arg.new("block", restriction: ProcNotation.new(["Int".path.splat] of ASTNode)), yields: 1)

  it_parses "def foo(x, *args, y = 2); 1; end", Def.new("foo", args: ["x".arg, "args".arg, Arg.new("y", default_value: 2.int32)], body: 1.int32, splat_index: 1)
  it_parses "def foo(x, *args, y = 2, w, z = 3); 1; end", Def.new("foo", args: ["x".arg, "args".arg, Arg.new("y", default_value: 2.int32), "w".arg, Arg.new("z", default_value: 3.int32)], body: 1.int32, splat_index: 1)
  it_parses "def foo(x, *, y); 1; end", Def.new("foo", args: ["x".arg, "".arg, "y".arg], body: 1.int32, splat_index: 1)
  assert_syntax_error "def foo(x, *); 1; end", "named arguments must follow bare *"

  assert_syntax_error "def foo(var = 1 : Int32); end", "the syntax for an argument with a default value V and type T is `arg : T = V`"
  assert_syntax_error "def foo(var = x : Int); end", "the syntax for an argument with a default value V and type T is `arg : T = V`"

  it_parses "def foo(**args)\n1\nend", Def.new("foo", body: 1.int32, double_splat: "args".arg)
  it_parses "def foo(x, **args)\n1\nend", Def.new("foo", body: 1.int32, args: ["x".arg], double_splat: "args".arg)
  it_parses "def foo(x, **args, &block)\n1\nend", Def.new("foo", body: 1.int32, args: ["x".arg], double_splat: "args".arg, block_arg: "block".arg, yields: 0)
  it_parses "def foo(**args)\nargs\nend", Def.new("foo", body: "args".var, double_splat: "args".arg)
  it_parses "def foo(x = 1, **args)\n1\nend", Def.new("foo", body: 1.int32, args: [Arg.new("x", default_value: 1.int32)], double_splat: "args".arg)
  it_parses "def foo(**args : Foo)\n1\nend", Def.new("foo", body: 1.int32, double_splat: Arg.new("args", restriction: "Foo".path))
  it_parses "def foo(**args : **Foo)\n1\nend", Def.new("foo", body: 1.int32, double_splat: Arg.new("args", restriction: DoubleSplat.new("Foo".path)))

  assert_syntax_error "def foo(**args, **args2); end", "only block argument is allowed after double splat"
  assert_syntax_error "def foo(**args, x); end", "only block argument is allowed after double splat"
  assert_syntax_error "def foo(**args, *x); end", "only block argument is allowed after double splat"

  it_parses "def foo(x y); y; end", Def.new("foo", args: [Arg.new("y", external_name: "x")], body: "y".var)
  it_parses "def foo(x @var); end", Def.new("foo", [Arg.new("var", external_name: "x")], [Assign.new("@var".instance_var, "var".var)] of ASTNode)
  it_parses "def foo(x @@var); end", Def.new("foo", [Arg.new("var", external_name: "x")], [Assign.new("@@var".class_var, "var".var)] of ASTNode)
  assert_syntax_error "def foo(_ y); y; end"

  it_parses %(def foo("bar qux" y); y; end), Def.new("foo", args: [Arg.new("y", external_name: "bar qux")], body: "y".var)

  assert_syntax_error "def foo(x x); 1; end", "when specified, external name must be different than internal name"
  assert_syntax_error "def foo(x @x); 1; end", "when specified, external name must be different than internal name"
  assert_syntax_error "def foo(x @@x); 1; end", "when specified, external name must be different than internal name"

  assert_syntax_error "def foo(*a foo); end"
  assert_syntax_error "def foo(**a foo); end"
  assert_syntax_error "def foo(&a foo); end"

  it_parses "macro foo(**args)\n1\nend", Macro.new("foo", body: MacroLiteral.new("1\n"), double_splat: "args".arg)

  assert_syntax_error "macro foo(x, *); 1; end", "named arguments must follow bare *"
  assert_syntax_error "macro foo(**x, **y)", "only block argument is allowed after double splat"
  assert_syntax_error "macro foo(**x, y)", "only block argument is allowed after double splat"

  it_parses "abstract def foo", Def.new("foo", abstract: true)
  it_parses "abstract def foo; 1", [Def.new("foo", abstract: true), 1.int32]
  it_parses "abstract def foo\n1", [Def.new("foo", abstract: true), 1.int32]
  it_parses "abstract def foo(x)", Def.new("foo", ["x".arg], abstract: true)

  assert_syntax_error "def foo var; end", "parentheses are mandatory for def arguments"
  assert_syntax_error "def foo var\n end", "parentheses are mandatory for def arguments"
  assert_syntax_error "def foo &block ; end", "parentheses are mandatory for def arguments"
  assert_syntax_error "def foo &block : Int -> Double ; end", "parentheses are mandatory for def arguments"
  assert_syntax_error "def foo @var, &block; end", "parentheses are mandatory for def arguments"
  assert_syntax_error "def foo @@var, &block; end", "parentheses are mandatory for def arguments"
  assert_syntax_error "def foo *y; 1; end", "parentheses are mandatory for def arguments"

  it_parses "def foo(x : U) forall U; end", Def.new("foo", args: [Arg.new("x", restriction: "U".path)], free_vars: %w(U))
  it_parses "def foo(x : U) forall T, U; end", Def.new("foo", args: [Arg.new("x", restriction: "U".path)], free_vars: %w(T U))
  it_parses "def foo(x : U) : Int32 forall T, U; end", Def.new("foo", args: [Arg.new("x", restriction: "U".path)], return_type: "Int32".path, free_vars: %w(T U))
  assert_syntax_error "def foo(x : U) forall; end"
  assert_syntax_error "def foo(x : U) forall U,; end"

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call(1.int32)
  it_parses "foo 1", "foo".call(1.int32)
  it_parses "foo 1\n", "foo".call(1.int32)
  it_parses "foo 1;", "foo".call(1.int32)
  it_parses "foo 1, 2", "foo".call(1.int32, 2.int32)
  it_parses "foo (1 + 2), 3", "foo".call(Expressions.new([Call.new(1.int32, "+", 2.int32)] of ASTNode), 3.int32)
  it_parses "foo(1 + 2)", "foo".call(Call.new(1.int32, "+", 2.int32))
  it_parses "foo -1.0, -2.0", "foo".call(-1.float64, -2.float64)
  it_parses "foo(\n1)", "foo".call(1.int32)
  it_parses "::foo", Call.new(nil, "foo", [] of ASTNode, nil, nil, nil, true)

  it_parses "foo + 1", Call.new("foo".call, "+", 1.int32)
  it_parses "foo +1", Call.new(nil, "foo", 1.int32)
  it_parses "foo +1.0", Call.new(nil, "foo", 1.float64)
  it_parses "foo +1_i64", Call.new(nil, "foo", 1.int64)
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, "+", 1.int32)]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, "-", 1.int32)]

  it_parses "foo(&block)", Call.new(nil, "foo", block_arg: "block".call)
  it_parses "foo &block", Call.new(nil, "foo", block_arg: "block".call)
  it_parses "a.foo &block", Call.new("a".call, "foo", block_arg: "block".call)
  it_parses "a.foo(&block)", Call.new("a".call, "foo", block_arg: "block".call)

  it_parses "foo(&.block)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "block")))
  it_parses "foo &.block", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "block")))
  it_parses "foo &./(1)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "/", 1.int32)))
  it_parses "foo &.%(1)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "%", 1.int32)))
  it_parses "foo &.block(1)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "block", 1.int32)))
  it_parses "foo &.+(2)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "+", 2.int32)))
  it_parses "foo &.bar.baz", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Call.new(Var.new("__arg0"), "bar"), "baz")))
  it_parses "foo(&.bar.baz)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Call.new(Var.new("__arg0"), "bar"), "baz")))
  it_parses "foo &.block[0]", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Call.new(Var.new("__arg0"), "block"), "[]", 0.int32)))
  it_parses "foo &.block=(0)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "block=", 0.int32)))
  it_parses "foo &.block = 0", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "block=", 0.int32)))
  it_parses "foo &.block[0] = 1", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Call.new(Var.new("__arg0"), "block"), "[]=", 0.int32, 1.int32)))
  it_parses "foo &.[0]", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "[]", 0.int32)))
  it_parses "foo &.[0] = 1", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Var.new("__arg0"), "[]=", 0.int32, 1.int32)))
  it_parses "foo(&.is_a?(T))", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], IsA.new(Var.new("__arg0"), "T".path)))
  it_parses "foo(&.responds_to?(:foo))", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], RespondsTo.new(Var.new("__arg0"), "foo")))
  it_parses "foo &.each {\n}", Call.new(nil, "foo", block: Block.new(["__arg0".var], Call.new("__arg0".var, "each", block: Block.new)))
  it_parses "foo &.each do\nend", Call.new(nil, "foo", block: Block.new(["__arg0".var], Call.new("__arg0".var, "each", block: Block.new)))

  it_parses "foo(&.as(T))", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Cast.new(Var.new("__arg0"), "T".path)))
  it_parses "foo(&.as(T).bar)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Cast.new(Var.new("__arg0"), "T".path), "bar")))
  it_parses "foo &.as(T)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Cast.new(Var.new("__arg0"), "T".path)))
  it_parses "foo &.as(T).bar", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(Cast.new(Var.new("__arg0"), "T".path), "bar")))

  it_parses "foo(&.as?(T))", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], NilableCast.new(Var.new("__arg0"), "T".path)))
  it_parses "foo(&.as?(T).bar)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(NilableCast.new(Var.new("__arg0"), "T".path), "bar")))
  it_parses "foo &.as?(T)", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], NilableCast.new(Var.new("__arg0"), "T".path)))
  it_parses "foo &.as?(T).bar", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], Call.new(NilableCast.new(Var.new("__arg0"), "T".path), "bar")))

  it_parses "foo.[0]", Call.new("foo".call, "[]", 0.int32)
  it_parses "foo.[0] = 1", Call.new("foo".call, "[]=", [0.int32, 1.int32] of ASTNode)

  it_parses "foo(a: 1, b: 2)", Call.new(nil, "foo", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "foo(1, a: 1, b: 2)", Call.new(nil, "foo", [1.int32] of ASTNode, named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "foo a: 1, b: 2", Call.new(nil, "foo", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "foo 1, a: 1, b: 2", Call.new(nil, "foo", [1.int32] of ASTNode, named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "foo 1, a: 1, b: 2\n1", [Call.new(nil, "foo", [1.int32] of ASTNode, named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)]), 1.int32]
  it_parses "foo(a: 1\n)", Call.new(nil, "foo", named_args: [NamedArgument.new("a", 1.int32)])
  it_parses "foo(\na: 1,\n)", Call.new(nil, "foo", named_args: [NamedArgument.new("a", 1.int32)])

  it_parses %(foo("foo bar": 1, "baz": 2)), Call.new(nil, "foo", named_args: [NamedArgument.new("foo bar", 1.int32), NamedArgument.new("baz", 2.int32)])
  it_parses %(foo "foo bar": 1, "baz": 2), Call.new(nil, "foo", named_args: [NamedArgument.new("foo bar", 1.int32), NamedArgument.new("baz", 2.int32)])

  it_parses "x.foo(a: 1, b: 2)", Call.new("x".call, "foo", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "x.foo a: 1, b: 2 ", Call.new("x".call, "foo", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])

  it_parses "x[a: 1, b: 2]", Call.new("x".call, "[]", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "x[a: 1, b: 2,]", Call.new("x".call, "[]", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])
  it_parses "x[{1}]", Call.new("x".call, "[]", TupleLiteral.new([1.int32] of ASTNode))
  it_parses "x[+ 1]", Call.new("x".call, "[]", Call.new(1.int32, "+"))

  it_parses "foo(a: 1, &block)", Call.new(nil, "foo", named_args: [NamedArgument.new("a", 1.int32)], block_arg: "block".call)
  it_parses "foo a: 1, &block", Call.new(nil, "foo", named_args: [NamedArgument.new("a", 1.int32)], block_arg: "block".call)
  it_parses "foo a: b(1) do\nend", Call.new(nil, "foo", named_args: [NamedArgument.new("a", Call.new(nil, "b", 1.int32))], block: Block.new)

  it_parses "Foo.bar x.y do\nend", Call.new("Foo".path, "bar", args: [Call.new("x".call, "y")] of ASTNode, block: Block.new)

  it_parses "x = 1; foo x do\nend", [Assign.new("x".var, 1.int32), Call.new(nil, "foo", ["x".var] of ASTNode, Block.new)]
  it_parses "x = 1; foo x { }", [Assign.new("x".var, 1.int32), Call.new(nil, "foo", [Call.new(nil, "x", block: Block.new)] of ASTNode)]
  it_parses "x = 1; foo x {\n}", [Assign.new("x".var, 1.int32), Call.new(nil, "foo", [Call.new(nil, "x", block: Block.new)] of ASTNode)]
  it_parses "foo x do\nend", Call.new(nil, "foo", ["x".call] of ASTNode, Block.new)
  it_parses "foo x, y do\nend", Call.new(nil, "foo", ["x".call, "y".call] of ASTNode, Block.new)
  it_parses "1.x; foo do\nend", [Call.new(1.int32, "x"), Call.new(nil, "foo", block: Block.new)] of ASTNode
  it_parses "x = 1; foo.bar x do\nend", [Assign.new("x".var, 1.int32), Call.new("foo".call, "bar", ["x".var] of ASTNode, Block.new)]

  it_parses "foo do\n//\nend", Call.new(nil, "foo", [] of ASTNode, Block.new(body: regex("")))
  it_parses "foo x do\n//\nend", Call.new(nil, "foo", ["x".call] of ASTNode, Block.new(body: regex("")))
  it_parses "foo(x) do\n//\nend", Call.new(nil, "foo", ["x".call] of ASTNode, Block.new(body: regex("")))

  it_parses "foo !false", Call.new(nil, "foo", [Not.new(false.bool)] of ASTNode)
  it_parses "!a && b", And.new(Not.new("a".call), "b".call)

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".path, "new")] of ASTNode)
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".path, "new")] of ASTNode)
  it_parses "f.x = - 1", Call.new("f".call, "x=", [Call.new(1.int32, "-")] of ASTNode)

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "f.x #{op}= 2", OpAssign.new(Call.new("f".call, "x"), op, 2.int32)
  end

  ["/", "<", "<=", "==", "!=", "=~", "!~", ">", ">=", "+", "-", "*", "/", "~", "%", "&", "|", "^", "**", "==="].each do |op|
    it_parses "def #{op}; end;", Def.new(op)
  end

  it_parses "def %(); end;", Def.new("%")
  it_parses "def /(); end;", Def.new("/")

  ["<<", "<", "<=", "==", ">>", ">", ">=", "+", "-", "*", "/", "%", "|", "&", "^", "**", "===", "=~", "!~"].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int32, op, 2.int32)
    it_parses "n #{op} 2", Call.new("n".call, op, 2.int32)
  end

  ["bar", "+", "-", "*", "/", "<", "<=", "==", ">", ">=", "%", "|", "&", "^", "**", "===", "=~", "!~"].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, 1.int32, 2.int32)
    it_parses "foo.#{name}(1, 2)", Call.new("foo".call, name, 1.int32, 2.int32)
  end

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "a = 1; a #{op}= 1", [Assign.new("a".var, 1.int32), OpAssign.new("a".var, op, 1.int32)]
    it_parses "a = 1; a #{op}=\n1", [Assign.new("a".var, 1.int32), OpAssign.new("a".var, op, 1.int32)]
    it_parses "a.b #{op}=\n1", OpAssign.new(Call.new("a".call, "b"), op, 1.int32)
  end

  it_parses "a = 1; a &&= 1", [Assign.new("a".var, 1.int32), OpAssign.new("a".var, "&&", 1.int32)]
  it_parses "a = 1; a ||= 1", [Assign.new("a".var, 1.int32), OpAssign.new("a".var, "||", 1.int32)]

  it_parses "a = 1; a[2] &&= 3", [Assign.new("a".var, 1.int32), OpAssign.new(Call.new("a".var, "[]", 2.int32), "&&", 3.int32)]
  it_parses "a = 1; a[2] ||= 3", [Assign.new("a".var, 1.int32), OpAssign.new(Call.new("a".var, "[]", 2.int32), "||", 3.int32)]

  it_parses "if foo; 1; end", If.new("foo".call, 1.int32)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int32)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int32, If.new("bar".call, 2.int32, 3.int32))

  it_parses "include Foo", Include.new("Foo".path)
  it_parses "include Foo\nif true; end", [Include.new("Foo".path), If.new(true.bool)]
  it_parses "extend Foo", Extend.new("Foo".path)
  it_parses "extend Foo\nif true; end", [Extend.new("Foo".path), If.new(true.bool)]
  it_parses "extend self", Extend.new(Self.new)

  it_parses "unless foo; 1; end", Unless.new("foo".call, 1.int32)
  it_parses "unless foo; 1; else; 2; end", Unless.new("foo".call, 1.int32, 2.int32)

  it_parses "class Foo; end", ClassDef.new("Foo".path)
  it_parses "class Foo\nend", ClassDef.new("Foo".path)
  it_parses "class Foo\ndef foo; end; end", ClassDef.new("Foo".path, [Def.new("foo")] of ASTNode)
  it_parses "class Foo < Bar; end", ClassDef.new("Foo".path, superclass: "Bar".path)
  it_parses "class Foo(T); end", ClassDef.new("Foo".path, type_vars: ["T"])
  it_parses "class Foo(T1); end", ClassDef.new("Foo".path, type_vars: ["T1"])
  it_parses "class Foo(Type); end", ClassDef.new("Foo".path, type_vars: ["Type"])
  it_parses "abstract class Foo; end", ClassDef.new("Foo".path, abstract: true)
  it_parses "abstract struct Foo; end", ClassDef.new("Foo".path, abstract: true, struct: true)

  it_parses "class Foo < self; end", ClassDef.new("Foo".path, superclass: Self.new)

  it_parses "module Foo(*T); end", ModuleDef.new("Foo".path, type_vars: ["T"], splat_index: 0)
  it_parses "class Foo(*T); end", ClassDef.new("Foo".path, type_vars: ["T"], splat_index: 0)
  it_parses "class Foo(T, *U); end", ClassDef.new("Foo".path, type_vars: ["T", "U"], splat_index: 1)
  assert_syntax_error "class Foo(*T, *U); end", "splat type argument already specified"

  it_parses "x : Foo(A, *B, C)", TypeDeclaration.new("x".var, Generic.new("Foo".path, ["A".path, "B".path.splat, "C".path] of ASTNode))
  it_parses "x : *T -> R", TypeDeclaration.new("x".var, ProcNotation.new(["T".path.splat] of ASTNode, "R".path))
  it_parses "def foo(x : *T -> R); end", Def.new("foo", args: [Arg.new("x", restriction: ProcNotation.new(["T".path.splat] of ASTNode, "R".path))])

  it_parses "struct Foo; end", ClassDef.new("Foo".path, struct: true)

  it_parses "Foo(T)", Generic.new("Foo".path, ["T".path] of ASTNode)
  it_parses "Foo(T | U)", Generic.new("Foo".path, [Crystal::Union.new(["T".path, "U".path] of ASTNode)] of ASTNode)
  it_parses "Foo(Bar(T | U))", Generic.new("Foo".path, [Generic.new("Bar".path, [Crystal::Union.new(["T".path, "U".path] of ASTNode)] of ASTNode)] of ASTNode)
  it_parses "Foo(T?)", Generic.new("Foo".path, [Crystal::Union.new(["T".path, Path.global("Nil")] of ASTNode)] of ASTNode)
  it_parses "Foo(1)", Generic.new("Foo".path, [1.int32] of ASTNode)
  it_parses "Foo(T, 1)", Generic.new("Foo".path, ["T".path, 1.int32] of ASTNode)
  it_parses "Foo(T, U, 1)", Generic.new("Foo".path, ["T".path, "U".path, 1.int32] of ASTNode)
  it_parses "Foo(T, 1, U)", Generic.new("Foo".path, ["T".path, 1.int32, "U".path] of ASTNode)
  it_parses "Foo(typeof(1))", Generic.new("Foo".path, [TypeOf.new([1.int32] of ASTNode)] of ASTNode)
  it_parses "Foo(typeof(1), typeof(2))", Generic.new("Foo".path, [TypeOf.new([1.int32] of ASTNode), TypeOf.new([2.int32] of ASTNode)] of ASTNode)
  it_parses "Foo({X, Y})", Generic.new("Foo".path, [Generic.new(Path.global("Tuple"), ["X".path, "Y".path] of ASTNode)] of ASTNode)
  it_parses "Foo({->})", Generic.new("Foo".path, [Generic.new(Path.global("Tuple"), [ProcNotation.new] of ASTNode)] of ASTNode)
  it_parses "Foo({String, ->})", Generic.new("Foo".path, [Generic.new(Path.global("Tuple"), ["String".path, ProcNotation.new] of ASTNode)] of ASTNode)
  it_parses "Foo({String, ->, ->})", Generic.new("Foo".path, [Generic.new(Path.global("Tuple"), ["String".path, ProcNotation.new, ProcNotation.new] of ASTNode)] of ASTNode)
  it_parses "[] of {String, ->}", ArrayLiteral.new([] of ASTNode, Generic.new(Path.global("Tuple"), ["String".path, ProcNotation.new] of ASTNode))
  it_parses "x([] of Foo, Bar.new)", Call.new(nil, "x", ArrayLiteral.new([] of ASTNode, "Foo".path), Call.new("Bar".path, "new"))

  it_parses "Foo(x: U)", Generic.new("Foo".path, [] of ASTNode, named_args: [NamedArgument.new("x", "U".path)])
  it_parses "Foo(x: U, y: V)", Generic.new("Foo".path, [] of ASTNode, named_args: [NamedArgument.new("x", "U".path), NamedArgument.new("y", "V".path)])
  assert_syntax_error "Foo(T, x: U)"

  it_parses %(Foo("foo bar": U)), Generic.new("Foo".path, [] of ASTNode, named_args: [NamedArgument.new("foo bar", "U".path)])
  it_parses %(Foo("foo": U, "bar": V)), Generic.new("Foo".path, [] of ASTNode, named_args: [NamedArgument.new("foo", "U".path), NamedArgument.new("bar", "V".path)])

  it_parses "Foo({x: X})", Generic.new("Foo".path, [Generic.new(Path.global("NamedTuple"), [] of ASTNode, named_args: [NamedArgument.new("x", "X".path)])] of ASTNode)
  it_parses "Foo({x: X, y: Y})", Generic.new("Foo".path, [Generic.new(Path.global("NamedTuple"), [] of ASTNode, named_args: [NamedArgument.new("x", "X".path), NamedArgument.new("y", "Y".path)])] of ASTNode)
  assert_syntax_error "Foo({x: X, x: Y})", "duplicated key: x"

  it_parses %(Foo({"foo bar": X})), Generic.new("Foo".path, [Generic.new(Path.global("NamedTuple"), [] of ASTNode, named_args: [NamedArgument.new("foo bar", "X".path)])] of ASTNode)
  it_parses %(Foo({"foo": X, "bar": Y})), Generic.new("Foo".path, [Generic.new(Path.global("NamedTuple"), [] of ASTNode, named_args: [NamedArgument.new("foo", "X".path), NamedArgument.new("bar", "Y".path)])] of ASTNode)

  it_parses %(Foo{"x" => "y"}), HashLiteral.new([HashLiteral::Entry.new("x".string, "y".string)], name: "Foo".path)
  it_parses %(::Foo{"x" => "y"}), HashLiteral.new([HashLiteral::Entry.new("x".string, "y".string)], name: Path.global("Foo"))

  it_parses "Foo(*T)", Generic.new("Foo".path, ["T".path.splat] of ASTNode)

  it_parses "Foo(X, sizeof(Int32))", Generic.new("Foo".path, ["X".path, SizeOf.new("Int32".path)] of ASTNode)
  it_parses "Foo(X, instance_sizeof(Int32))", Generic.new("Foo".path, ["X".path, InstanceSizeOf.new("Int32".path)] of ASTNode)

  it_parses "Foo(\nT\n)", Generic.new("Foo".path, ["T".path] of ASTNode)
  it_parses "Foo(\nT,\nU,\n)", Generic.new("Foo".path, ["T".path, "U".path] of ASTNode)
  it_parses "Foo(\nx:\nT,\ny:\nU,\n)", Generic.new("Foo".path, [] of ASTNode, named_args: [NamedArgument.new("x", "T".path), NamedArgument.new("y", "U".path)])

  it_parses "module Foo; end", ModuleDef.new("Foo".path)
  it_parses "module Foo\ndef foo; end; end", ModuleDef.new("Foo".path, [Def.new("foo")] of ASTNode)
  it_parses "module Foo(T); end", ModuleDef.new("Foo".path, type_vars: ["T"])

  it_parses "while true; end;", While.new(true.bool)
  it_parses "while true; 1; end;", While.new(true.bool, 1.int32)

  it_parses "until true; end;", Until.new(true.bool)
  it_parses "until true; 1; end;", Until.new(true.bool, 1.int32)

  it_parses "foo do; 1; end", Call.new(nil, "foo", block: Block.new(body: 1.int32))
  it_parses "foo do |a|; 1; end", Call.new(nil, "foo", block: Block.new(["a".var], 1.int32))

  it_parses "foo { 1 }", Call.new(nil, "foo", block: Block.new(body: 1.int32))
  it_parses "foo { |a| 1 }", Call.new(nil, "foo", block: Block.new(["a".var], 1.int32))
  it_parses "foo { |a, b| 1 }", Call.new(nil, "foo", block: Block.new(["a".var, "b".var], 1.int32))
  it_parses "1.foo do; 1; end", Call.new(1.int32, "foo", block: Block.new(body: 1.int32))
  it_parses "a b() {}", Call.new(nil, "a", Call.new(nil, "b", block: Block.new))

  it_parses "foo { |a, (b, c), (d, e)| a; b; c; d; e }", Call.new(nil, "foo",
    block: Block.new(["a".var, "__arg0".var, "__arg1".var],
      Expressions.new([
        Assign.new("b".var, Call.new("__arg0".var, "[]", 0.int32)),
        Assign.new("c".var, Call.new("__arg0".var, "[]", 1.int32)),
        Assign.new("d".var, Call.new("__arg1".var, "[]", 0.int32)),
        Assign.new("e".var, Call.new("__arg1".var, "[]", 1.int32)),
        "a".var, "b".var, "c".var, "d".var, "e".var,
      ] of ASTNode)))

  it_parses "foo { |(_, c)| c }", Call.new(nil, "foo",
    block: Block.new(["__arg0".var],
      Expressions.new([
        Assign.new("c".var, Call.new("__arg0".var, "[]", 1.int32)),
        "c".var,
      ] of ASTNode)))

  it_parses "1 ? 2 : 3", If.new(1.int32, 2.int32, 3.int32)
  it_parses "1 ? a : b", If.new(1.int32, "a".call, "b".call)
  it_parses "1 ? a : b ? c : 3", If.new(1.int32, "a".call, If.new("b".call, "c".call, 3.int32))
  it_parses "a ? 1 : b ? 2 : c ? 3 : 0", If.new("a".call, 1.int32, If.new("b".call, 2.int32, If.new("c".call, 3.int32, 0.int32)))
  it_parses "a ? 1
             : b", If.new("a".call, 1.int32, "b".call)
  it_parses "a ? 1 :
             b ? 2 :
             c ? 3
             : 0", If.new("a".call, 1.int32, If.new("b".call, 2.int32, If.new("c".call, 3.int32, 0.int32)))
  it_parses "a ? 1
             : b ? 2
             : c ? 3
             : 0", If.new("a".call, 1.int32, If.new("b".call, 2.int32, If.new("c".call, 3.int32, 0.int32)))
  it_parses "a ?
             b ? b1 : b2
             : c ? 3
             : 0", If.new("a".call, If.new("b".call, "b1".call, "b2".call), If.new("c".call, 3.int32, 0.int32))

  it_parses "1 if 3", If.new(3.int32, 1.int32)
  it_parses "1 unless 3", Unless.new(3.int32, 1.int32)
  it_parses "r = 1; r.x += 2", [Assign.new("r".var, 1.int32), OpAssign.new(Call.new("r".var, "x"), "+", 2.int32)] of ASTNode

  it_parses "foo if 3", If.new(3.int32, "foo".call)
  it_parses "foo unless 3", Unless.new(3.int32, "foo".call)

  it_parses "a = 1; a += 10 if a += 20", [Assign.new("a".var, 1.int32), If.new(OpAssign.new("a".var, "+", 20.int32), OpAssign.new("a".var, "+", 10.int32))]
  it_parses "puts a if true", If.new(true.bool, Call.new(nil, "puts", "a".call))
  it_parses "puts ::foo", Call.new(nil, "puts", Call.new(nil, "foo", global: true))

  it_parses "puts __FILE__", Call.new(nil, "puts", "/foo/bar/baz.cr".string)
  it_parses "puts __DIR__", Call.new(nil, "puts", "/foo/bar".string)
  it_parses "puts __LINE__", Call.new(nil, "puts", 1.int32)
  it_parses "puts _", Call.new(nil, "puts", Underscore.new)

  it_parses "x = 2; foo do bar x end", [Assign.new("x".var, 2.int32), Call.new(nil, "foo", block: Block.new(body: Call.new(nil, "bar", "x".var)))] of ASTNode

  { {"break", Break}, {"return", Return}, {"next", Next} }.each do |(keyword, klass)|
    it_parses "#{keyword}", klass.new
    it_parses "#{keyword};", klass.new
    it_parses "#{keyword} 1", klass.new(1.int32)
    it_parses "#{keyword} 1, 2", klass.new(TupleLiteral.new([1.int32, 2.int32] of ASTNode))
    it_parses "#{keyword} {1, 2}", klass.new(TupleLiteral.new([1.int32, 2.int32] of ASTNode))
    it_parses "#{keyword} {1 => 2}", klass.new(HashLiteral.new([HashLiteral::Entry.new(1.int32, 2.int32)]))
    it_parses "#{keyword} 1 if true", If.new(true.bool, klass.new(1.int32))
    it_parses "#{keyword} if true", If.new(true.bool, klass.new)

    assert_syntax_error "a = #{keyword}", "void value expression"
    assert_syntax_error "a = 1; a += #{keyword}", "void value expression"
    assert_syntax_error "yield #{keyword}", "void value expression"
    assert_syntax_error "foo(#{keyword})", "void value expression"
    assert_syntax_error "foo[#{keyword}]", "void value expression"
    assert_syntax_error "foo[1] = #{keyword}", "void value expression"
    assert_syntax_error "if #{keyword}; end", "void value expression"
    assert_syntax_error "unless #{keyword}; end", "void value expression"
    assert_syntax_error "while #{keyword}; end", "void value expression"
    assert_syntax_error "until #{keyword}; end", "void value expression"
    assert_syntax_error "1 if #{keyword}", "void value expression"
    assert_syntax_error "1 unless #{keyword}", "void value expression"
    assert_syntax_error "#{keyword}.foo", "void value expression"
    assert_syntax_error "#{keyword}.as(Int32)", "void value expression"
    assert_syntax_error "#{keyword}[]", "void value expression"
    assert_syntax_error "#{keyword}[0]", "void value expression"
    assert_syntax_error "#{keyword}[0]= 1", "void value expression"
    assert_syntax_error "#{keyword} .. 1", "void value expression"
    assert_syntax_error "#{keyword} ... 1", "void value expression"
    assert_syntax_error "1 .. #{keyword}", "void value expression"
    assert_syntax_error "1 ... #{keyword}", "void value expression"
    assert_syntax_error "#{keyword} ? 1 : 2", "void value expression"
    assert_syntax_error "+#{keyword}", "void value expression"

    ["<<", "<", "<=", "==", ">>", ">", ">=", "+", "-", "*", "/", "%", "|", "&", "^", "**", "==="].each do |op|
      assert_syntax_error "#{keyword} #{op} 1", "void value expression"
    end

    assert_syntax_error "case #{keyword}; when 1; end; end", "void value expression"
    assert_syntax_error "case 1; when #{keyword}; end; end", "void value expression"
  end

  it_parses "yield", Yield.new
  it_parses "yield;", Yield.new
  it_parses "yield 1", Yield.new([1.int32] of ASTNode)
  it_parses "yield 1 if true", If.new(true.bool, Yield.new([1.int32] of ASTNode))
  it_parses "yield if true", If.new(true.bool, Yield.new)

  it_parses "Int", "Int".path

  it_parses "Int[]", Call.new("Int".path, "[]")
  it_parses "def []; end", Def.new("[]")
  it_parses "def []?; end", Def.new("[]?")
  it_parses "def []=(value); end", Def.new("[]=", ["value".arg])
  it_parses "def self.[]; end", Def.new("[]", receiver: "self".var)
  it_parses "def self.[]?; end", Def.new("[]?", receiver: "self".var)

  it_parses "Int[8]", Call.new("Int".path, "[]", 8.int32)
  it_parses "Int[8, 4]", Call.new("Int".path, "[]", 8.int32, 4.int32)
  it_parses "Int[8, 4,]", Call.new("Int".path, "[]", 8.int32, 4.int32)
  it_parses "Int[8]?", Call.new("Int".path, "[]?", 8.int32)
  it_parses "x[0] ? 1 : 0", If.new(Call.new("x".call, "[]", 0.int32), 1.int32, 0.int32)

  it_parses "def [](x); end", Def.new("[]", ["x".arg])

  it_parses "foo[0] = 1", Call.new("foo".call, "[]=", 0.int32, 1.int32)
  it_parses "foo[0] = 1 if 2", If.new(2.int32, Call.new("foo".call, "[]=", 0.int32, 1.int32))

  it_parses "begin; 1; end;", Expressions.new([1.int32] of ASTNode)
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

  it_parses "call @foo.bar", Call.new(nil, "call", Call.new("@foo".instance_var, "bar"))
  it_parses "call \"foo\"", Call.new(nil, "call", "foo".string)

  it_parses "def foo; end; if false; 1; else; 2; end", [Def.new("foo", [] of Arg), If.new(false.bool, 1.int32, 2.int32)]

  it_parses "A.new(\"x\", B.new(\"y\"))", Call.new("A".path, "new", "x".string, Call.new("B".path, "new", "y".string))

  it_parses "foo [1]", Call.new(nil, "foo", ([1.int32] of ASTNode).array)
  it_parses "foo.bar [1]", Call.new("foo".call, "bar", ([1.int32] of ASTNode).array)

  it_parses "class Foo; end\nwhile true; end", [ClassDef.new("Foo".path), While.new(true.bool)]
  it_parses "while true; end\nif true; end", [While.new(true.bool), If.new(true.bool)]
  it_parses "(1)\nif true; end", [Expressions.new([1.int32] of ASTNode), If.new(true.bool)]
  it_parses "begin\n1\nend\nif true; end", [Expressions.new([1.int32] of ASTNode), If.new(true.bool)]

  it_parses "Foo::Bar", ["Foo", "Bar"].path

  it_parses "lib LibC\nend", LibDef.new("LibC")
  it_parses "lib LibC\nfun getchar\nend", LibDef.new("LibC", [FunDef.new("getchar")] of ASTNode)
  it_parses "lib LibC\nfun getchar(...)\nend", LibDef.new("LibC", [FunDef.new("getchar", varargs: true)] of ASTNode)
  it_parses "lib LibC\nfun getchar : Int\nend", LibDef.new("LibC", [FunDef.new("getchar", return_type: "Int".path)] of ASTNode)
  it_parses "lib LibC\nfun getchar : (->)?\nend", LibDef.new("LibC", [FunDef.new("getchar", return_type: Crystal::Union.new([ProcNotation.new, "Nil".path(true)] of ASTNode))] of ASTNode)
  it_parses "lib LibC\nfun getchar(Int, Float)\nend", LibDef.new("LibC", [FunDef.new("getchar", [Arg.new("", restriction: "Int".path), Arg.new("", restriction: "Float".path)])] of ASTNode)
  it_parses "lib LibC\nfun getchar(a : Int, b : Float)\nend", LibDef.new("LibC", [FunDef.new("getchar", [Arg.new("a", restriction: "Int".path), Arg.new("b", restriction: "Float".path)])] of ASTNode)
  it_parses "lib LibC\nfun getchar(a : Int)\nend", LibDef.new("LibC", [FunDef.new("getchar", [Arg.new("a", restriction: "Int".path)])] of ASTNode)
  it_parses "lib LibC\nfun getchar(a : Int, b : Float) : Int\nend", LibDef.new("LibC", [FunDef.new("getchar", [Arg.new("a", restriction: "Int".path), Arg.new("b", restriction: "Float".path)], "Int".path)] of ASTNode)
  it_parses "lib LibC; fun getchar(a : Int, b : Float) : Int; end", LibDef.new("LibC", [FunDef.new("getchar", [Arg.new("a", restriction: "Int".path), Arg.new("b", restriction: "Float".path)], "Int".path)] of ASTNode)
  it_parses "lib LibC; fun foo(a : Int*); end", LibDef.new("LibC", [FunDef.new("foo", [Arg.new("a", restriction: "Int".path.pointer_of)])] of ASTNode)
  it_parses "lib LibC; fun foo(a : Int**); end", LibDef.new("LibC", [FunDef.new("foo", [Arg.new("a", restriction: "Int".path.pointer_of.pointer_of)])] of ASTNode)
  it_parses "lib LibC; fun foo : Int*; end", LibDef.new("LibC", [FunDef.new("foo", return_type: "Int".path.pointer_of)] of ASTNode)
  it_parses "lib LibC; fun foo : Int**; end", LibDef.new("LibC", [FunDef.new("foo", return_type: "Int".path.pointer_of.pointer_of)] of ASTNode)
  it_parses "lib LibC; fun foo(a : ::B, ::C -> ::D); end", LibDef.new("LibC", [FunDef.new("foo", [Arg.new("a", restriction: ProcNotation.new([Path.global("B"), Path.global("C")] of ASTNode, Path.global("D")))])] of ASTNode)
  it_parses "lib LibC; type A = B; end", LibDef.new("LibC", [TypeDef.new("A", "B".path)] of ASTNode)
  it_parses "lib LibC; type A = B*; end", LibDef.new("LibC", [TypeDef.new("A", "B".path.pointer_of)] of ASTNode)
  it_parses "lib LibC; type A = B**; end", LibDef.new("LibC", [TypeDef.new("A", "B".path.pointer_of.pointer_of)] of ASTNode)
  it_parses "lib LibC; type A = B.class; end", LibDef.new("LibC", [TypeDef.new("A", Metaclass.new("B".path))] of ASTNode)
  it_parses "lib LibC; struct Foo; end end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo")] of ASTNode)
  it_parses "lib LibC; struct Foo; x : Int; y : Float; end end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo", [TypeDeclaration.new("x".var, "Int".path), TypeDeclaration.new("y".var, "Float".path)] of ASTNode)] of ASTNode)
  it_parses "lib LibC; struct Foo; x : Int*; end end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo", Expressions.from(TypeDeclaration.new("x".var, "Int".path.pointer_of)))] of ASTNode)
  it_parses "lib LibC; struct Foo; x : Int**; end end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo", Expressions.from(TypeDeclaration.new("x".var, "Int".path.pointer_of.pointer_of)))] of ASTNode)
  it_parses "lib LibC; struct Foo; x, y, z : Int; end end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo", [TypeDeclaration.new("x".var, "Int".path), TypeDeclaration.new("y".var, "Int".path), TypeDeclaration.new("z".var, "Int".path)] of ASTNode)] of ASTNode)
  it_parses "lib LibC; union Foo; end end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo", union: true)] of ASTNode)
  it_parses "lib LibC; enum Foo; A\nB, C\nD = 1; end end", LibDef.new("LibC", [EnumDef.new("Foo".path, [Arg.new("A"), Arg.new("B"), Arg.new("C"), Arg.new("D", 1.int32)] of ASTNode)] of ASTNode)
  it_parses "lib LibC; enum Foo; A = 1, B; end end", LibDef.new("LibC", [EnumDef.new("Foo".path, [Arg.new("A", 1.int32), Arg.new("B")] of ASTNode)] of ASTNode)
  it_parses "lib LibC; Foo = 1; end", LibDef.new("LibC", [Assign.new("Foo".path, 1.int32)] of ASTNode)
  it_parses "lib LibC\nfun getch = GetChar\nend", LibDef.new("LibC", [FunDef.new("getch", real_name: "GetChar")] of ASTNode)
  it_parses %(lib LibC\nfun getch = "get.char"\nend), LibDef.new("LibC", [FunDef.new("getch", real_name: "get.char")] of ASTNode)
  it_parses %(lib LibC\nfun getch = "get.char" : Int32\nend), LibDef.new("LibC", [FunDef.new("getch", return_type: "Int32".path, real_name: "get.char")] of ASTNode)
  it_parses %(lib LibC\nfun getch = "get.char"(x : Int32)\nend), LibDef.new("LibC", [FunDef.new("getch", [Arg.new("x", restriction: "Int32".path)], real_name: "get.char")] of ASTNode)
  it_parses "lib LibC\n$errno : Int32\n$errno2 : Int32\nend", LibDef.new("LibC", [ExternalVar.new("errno", "Int32".path), ExternalVar.new("errno2", "Int32".path)] of ASTNode)
  it_parses "lib LibC\n$errno : B, C -> D\nend", LibDef.new("LibC", [ExternalVar.new("errno", ProcNotation.new(["B".path, "C".path] of ASTNode, "D".path))] of ASTNode)
  it_parses "lib LibC\n$errno = Foo : Int32\nend", LibDef.new("LibC", [ExternalVar.new("errno", "Int32".path, "Foo")] of ASTNode)
  it_parses "lib LibC\nalias Foo = Bar\nend", LibDef.new("LibC", [Alias.new("Foo", "Bar".path)] of ASTNode)
  it_parses "lib LibC; struct Foo; include Bar; end; end", LibDef.new("LibC", [CStructOrUnionDef.new("Foo", Include.new("Bar".path))] of ASTNode)

  it_parses "lib LibC\nfun SomeFun\nend", LibDef.new("LibC", [FunDef.new("SomeFun")] of ASTNode)

  it_parses "fun foo(x : Int32) : Int64\nx\nend", FunDef.new("foo", [Arg.new("x", restriction: "Int32".path)], "Int64".path, body: "x".var)
  assert_syntax_error "fun Foo : Int64\nend"

  it_parses "lib LibC; {{ 1 }}; end", LibDef.new("LibC", body: [MacroExpression.new(1.int32)] of ASTNode)
  it_parses "lib LibC; {% if 1 %}2{% end %}; end", LibDef.new("LibC", body: [MacroIf.new(1.int32, MacroLiteral.new("2"))] of ASTNode)

  it_parses "lib LibC; struct Foo; {{ 1 }}; end; end", LibDef.new("LibC", body: CStructOrUnionDef.new("Foo", Expressions.from([MacroExpression.new(1.int32)] of ASTNode)))
  it_parses "lib LibC; struct Foo; {% if 1 %}2{% end %}; end; end", LibDef.new("LibC", body: CStructOrUnionDef.new("Foo", Expressions.from([MacroIf.new(1.int32, MacroLiteral.new("2"))] of ASTNode)))

  it_parses "1 .. 2", RangeLiteral.new(1.int32, 2.int32, false)
  it_parses "1 ... 2", RangeLiteral.new(1.int32, 2.int32, true)

  it_parses "A = 1", Assign.new("A".path, 1.int32)

  it_parses "puts %w(one two)", Call.new(nil, "puts", (["one".string, "two".string] of ASTNode).array_of(Path.global("String")))
  it_parses "puts %w{one two}", Call.new(nil, "puts", (["one".string, "two".string] of ASTNode).array_of(Path.global("String")))
  it_parses "puts %i(one two)", Call.new(nil, "puts", (["one".symbol, "two".symbol] of ASTNode).array_of(Path.global("Symbol")))
  it_parses "puts {{1}}", Call.new(nil, "puts", MacroExpression.new(1.int32))
  it_parses "puts {{\n1\n}}", Call.new(nil, "puts", MacroExpression.new(1.int32))
  it_parses "puts {{*1}}", Call.new(nil, "puts", MacroExpression.new(1.int32.splat))
  it_parses "puts {{**1}}", Call.new(nil, "puts", MacroExpression.new(DoubleSplat.new(1.int32)))
  it_parses "{{a = 1 if 2}}", MacroExpression.new(If.new(2.int32, Assign.new("a".var, 1.int32)))
  it_parses "{% a = 1 %}", MacroExpression.new(Assign.new("a".var, 1.int32), output: false)
  it_parses "{%\na = 1\n%}", MacroExpression.new(Assign.new("a".var, 1.int32), output: false)
  it_parses "{% a = 1 if 2 %}", MacroExpression.new(If.new(2.int32, Assign.new("a".var, 1.int32)), output: false)
  it_parses "{% if 1; 2; end %}", MacroExpression.new(If.new(1.int32, 2.int32), output: false)
  it_parses "{% unless 1; 2; end %}", MacroExpression.new(If.new(1.int32, Nop.new, 2.int32), output: false)
  it_parses "{%\n1\n2\n3\n%}", MacroExpression.new(Expressions.new([1.int32, 2.int32, 3.int32] of ASTNode), output: false)

  it_parses "[] of Int", ([] of ASTNode).array_of("Int".path)
  it_parses "[1, 2] of Int", ([1.int32, 2.int32] of ASTNode).array_of("Int".path)

  it_parses "::A::B", Path.global(["A", "B"])

  assert_syntax_error "$foo", "$global_variables are not supported, use @@class_variables instead"

  it_parses "macro foo;end", Macro.new("foo", [] of Arg, Expressions.new)
  it_parses "macro [];end", Macro.new("[]", [] of Arg, Expressions.new)
  it_parses "macro %();end", Macro.new("%", [] of Arg, Expressions.new)
  it_parses "macro /();end", Macro.new("/", [] of Arg, Expressions.new)
  it_parses %(macro foo; 1 + 2; end), Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses %(macro foo(x); 1 + 2; end), Macro.new("foo", ([Arg.new("x")]), Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses %(macro foo(x)\n 1 + 2; end), Macro.new("foo", ([Arg.new("x")]), Expressions.from([" 1 + 2; ".macro_literal] of ASTNode))
  it_parses "macro foo; 1 + 2 {{foo}} 3 + 4; end", Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2 ".macro_literal, MacroExpression.new("foo".var), " 3 + 4; ".macro_literal] of ASTNode))
  it_parses "macro foo; 1 + 2 {{ foo }} 3 + 4; end", Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2 ".macro_literal, MacroExpression.new("foo".var), " 3 + 4; ".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% for x in y %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var], "y".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% for x, y in z %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var, "y".var], "z".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% else %}body2{%end%}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal, "body2".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% elsif y %}body2{%end%}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal, MacroIf.new("y".var, "body2".macro_literal)), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% if x %}body{% elsif y %}body2{% else %}body3{%end%}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, "body".macro_literal, MacroIf.new("y".var, "body2".macro_literal, "body3".macro_literal)), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% unless x %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new("x".var, Nop.new, "body".macro_literal), "baz;".macro_literal] of ASTNode))

  it_parses "macro foo;bar{% for x in y %}\\  \n   body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var], "y".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo;bar{% for x in y %}\\  \n   body{% end %}\\   baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroFor.new(["x".var], "y".var, "body".macro_literal), "baz;".macro_literal] of ASTNode))
  it_parses "macro foo; 1 + 2 {{foo}}\\ 3 + 4; end", Macro.new("foo", [] of Arg, Expressions.from([" 1 + 2 ".macro_literal, MacroExpression.new("foo".var), "3 + 4; ".macro_literal] of ASTNode))

  assert_syntax_error "macro def foo : String; 1; end"

  it_parses "def foo;{{@type}};end", Def.new("foo", body: Expressions.from([MacroExpression.new("@type".instance_var)] of ASTNode), macro_def: true)

  it_parses "macro foo;bar{% begin %}body{% end %}baz;end", Macro.new("foo", [] of Arg, Expressions.from(["bar".macro_literal, MacroIf.new(true.bool, "body".macro_literal), "baz;".macro_literal] of ASTNode))

  it_parses "macro x\n%{}\nend", Macro.new("x", body: MacroLiteral.new("%{}\n"))

  it_parses "def foo : Int32\n1\nend", Def.new("foo", body: 1.int32, return_type: "Int32".path)
  it_parses "def foo(x) : Int32\n1\nend", Def.new("foo", args: ["x".arg], body: 1.int32, return_type: "Int32".path)

  it_parses "abstract def foo : Int32", Def.new("foo", return_type: "Int32".path, abstract: true)
  it_parses "abstract def foo(x) : Int32", Def.new("foo", args: ["x".arg], return_type: "Int32".path, abstract: true)

  it_parses "{% for x in y %}body{% end %}", MacroFor.new(["x".var], "y".var, "body".macro_literal)
  it_parses "{% if x %}body{% end %}", MacroIf.new("x".var, "body".macro_literal)
  it_parses "{% begin %}{% if true %}if true{% end %}\n{% if true %}end{% end %}{% end %}", MacroIf.new(true.bool, [MacroIf.new(true.bool, "if true".macro_literal), "\n".macro_literal, MacroIf.new(true.bool, "end".macro_literal)] of ASTNode)
  it_parses "{{ foo }}", MacroExpression.new("foo".var)

  it_parses "macro foo;%var;end", Macro.new("foo", [] of Arg, Expressions.from([MacroVar.new("var"), MacroLiteral.new(";")] of ASTNode))
  it_parses "macro foo;%var{1, x} = hello;end", Macro.new("foo", [] of Arg, Expressions.from([MacroVar.new("var", [1.int32, "x".var] of ASTNode), MacroLiteral.new(" = hello;")] of ASTNode))

  ["if", "unless"].each do |keyword|
    it_parses "macro foo;%var #{keyword} true;end", Macro.new("foo", [] of Arg, Expressions.from([MacroVar.new("var"), " #{keyword} true;".macro_literal] of ASTNode))
    it_parses "macro foo;var #{keyword} true;end", Macro.new("foo", [] of Arg, "var #{keyword} true;".macro_literal)
    it_parses "macro foo;#{keyword} %var;true;end;end", Macro.new("foo", [] of Arg, Expressions.from(["#{keyword} ".macro_literal, MacroVar.new("var"), ";true;".macro_literal, "end;".macro_literal] of ASTNode))
    it_parses "macro foo;#{keyword} var;true;end;end", Macro.new("foo", [] of Arg, Expressions.from(["#{keyword} var;true;".macro_literal, "end;".macro_literal] of ASTNode))
  end

  it_parses "a = 1; pointerof(a)", [Assign.new("a".var, 1.int32), PointerOf.new("a".var)]
  it_parses "pointerof(@a)", PointerOf.new("@a".instance_var)
  it_parses "a = 1; pointerof(a)", [Assign.new("a".var, 1.int32), PointerOf.new("a".var)]
  it_parses "pointerof(@a)", PointerOf.new("@a".instance_var)

  it_parses "sizeof(X)", SizeOf.new("X".path)
  it_parses "instance_sizeof(X)", InstanceSizeOf.new("X".path)

  it_parses "foo.is_a?(Const)", IsA.new("foo".call, "Const".path)
  it_parses "foo.is_a?(Foo | Bar)", IsA.new("foo".call, Crystal::Union.new(["Foo".path, "Bar".path] of ASTNode))
  it_parses "foo.is_a? Const", IsA.new("foo".call, "Const".path)
  it_parses "foo.responds_to?(:foo)", RespondsTo.new("foo".call, "foo")
  it_parses "foo.responds_to? :foo", RespondsTo.new("foo".call, "foo")
  it_parses "if foo.responds_to? :foo\nx = 1\nend", If.new(RespondsTo.new("foo".call, "foo"), Assign.new("x".var, 1.int32))

  it_parses "is_a?(Const)", IsA.new("self".var, "Const".path)
  it_parses "responds_to?(:foo)", RespondsTo.new("self".var, "foo")
  it_parses "nil?", IsA.new("self".var, Path.global("Nil"), nil_check: true)
  it_parses "nil?(  )", IsA.new("self".var, Path.global("Nil"), nil_check: true)

  it_parses "foo.nil?", IsA.new("foo".call, Path.global("Nil"), nil_check: true)
  it_parses "foo.nil?(  )", IsA.new("foo".call, Path.global("Nil"), nil_check: true)

  it_parses "foo &.nil?", Call.new(nil, "foo", block: Block.new([Var.new("__arg0")], IsA.new(Var.new("__arg0"), Path.global("Nil"), nil_check: true)))
  it_parses "foo &.baz.qux do\nend", Call.new(nil, "foo",
    block: Block.new(["__arg0".var],
      Call.new(Call.new("__arg0".var, "baz"), "qux", block: Block.new)
    )
  )

  it_parses "/foo/", regex("foo")
  it_parses "/foo/i", regex("foo", Regex::Options::IGNORE_CASE)
  it_parses "/foo/m", regex("foo", Regex::Options::MULTILINE)
  it_parses "/foo/x", regex("foo", Regex::Options::EXTENDED)
  it_parses "/foo/imximx", regex("foo", Regex::Options::IGNORE_CASE | Regex::Options::MULTILINE | Regex::Options::EXTENDED)
  it_parses "/fo\\so/", regex("fo\\so")
  it_parses "/fo\#{1}o/", RegexLiteral.new(StringInterpolation.new(["fo".string, 1.int32, "o".string] of ASTNode))
  it_parses "/(fo\#{\"bar\"}\#{1}o)/", RegexLiteral.new(StringInterpolation.new(["(fo".string, "bar".string, 1.int32, "o)".string] of ASTNode))
  it_parses "%r(foo(bar))", regex("foo(bar)")
  it_parses "/ /", regex(" ")
  it_parses "/=/", regex("=")
  it_parses "/ hi /", regex(" hi ")
  it_parses "self / number", Call.new("self".var, "/", "number".call)
  it_parses "a == / /", Call.new("a".call, "==", regex(" "))
  it_parses "/ /", regex(" ")
  it_parses "/ /; / /", [regex(" "), regex(" ")] of ASTNode
  it_parses "/ /\n/ /", [regex(" "), regex(" ")] of ASTNode
  it_parses "a = / /", Assign.new("a".var, regex(" "))
  it_parses "a = /=/", Assign.new("a".var, regex("="))
  it_parses "a; if / /; / /; elsif / /; / /; end", ["a".call, If.new(regex(" "), regex(" "), If.new(regex(" "), regex(" ")))]
  it_parses "a; if / /\n/ /\nelsif / /\n/ /\nend", ["a".call, If.new(regex(" "), regex(" "), If.new(regex(" "), regex(" ")))]
  it_parses "a; while / /; / /; end", ["a".call, While.new(regex(" "), regex(" "))]
  it_parses "a\nwhile / /\n/ /\nend", ["a".call, While.new(regex(" "), regex(" "))]
  it_parses "[/ /, / /]", ArrayLiteral.new([regex(" "), regex(" ")] of ASTNode)
  it_parses "{/ / => / /, / / => / /}", HashLiteral.new([HashLiteral::Entry.new(regex(" "), regex(" ")), HashLiteral::Entry.new(regex(" "), regex(" "))])
  it_parses "{/ /, / /}", TupleLiteral.new([regex(" "), regex(" ")] of ASTNode)
  it_parses "begin; / /; end", Expressions.new([regex(" ")] of ASTNode)
  it_parses "begin\n/ /\nend", Expressions.new([regex(" ")] of ASTNode)
  it_parses "/\\//", regex("/")
  it_parses "%r(/)", regex("/")
  it_parses "a()/3", Call.new("a".call, "/", 3.int32)
  it_parses "a() /3", Call.new("a".call, "/", 3.int32)
  it_parses "a.b() /3", Call.new(Call.new("a".call, "b"), "/", 3.int32)

  it_parses "1 =~ 2", Call.new(1.int32, "=~", 2.int32)
  it_parses "1.=~(2)", Call.new(1.int32, "=~", 2.int32)
  it_parses "def =~; end", Def.new("=~", [] of Arg)

  it_parses "$~", Global.new("$~")
  it_parses "$~.foo", Call.new(Global.new("$~"), "foo")
  it_parses "$0", Call.new(Global.new("$~"), "[]", 0.int32)
  it_parses "$1", Call.new(Global.new("$~"), "[]", 1.int32)
  it_parses "$1?", Call.new(Global.new("$~"), "[]?", 1.int32)
  it_parses "foo $1", Call.new(nil, "foo", Call.new(Global.new("$~"), "[]", 1.int32))
  it_parses "$~ = 1", Assign.new("$~".var, 1.int32)

  it_parses "foo /a/", Call.new(nil, "foo", regex("a"))
  it_parses "foo(/a/)", Call.new(nil, "foo", regex("a"))
  it_parses "foo(/ /)", Call.new(nil, "foo", regex(" "))
  it_parses "foo(/ /, / /)", Call.new(nil, "foo", [regex(" "), regex(" ")] of ASTNode)
  it_parses "foo a, / /", Call.new(nil, "foo", ["a".call, regex(" ")] of ASTNode)

  it_parses "$?", Global.new("$?")
  it_parses "$?.foo", Call.new(Global.new("$?"), "foo")
  it_parses "foo $?", Call.new(nil, "foo", Global.new("$?"))
  it_parses "$? = 1", Assign.new("$?".var, 1.int32)

  it_parses "foo out x; x", [Call.new(nil, "foo", Out.new("x".var)), "x".var]
  it_parses "foo(out x); x", [Call.new(nil, "foo", Out.new("x".var)), "x".var]
  it_parses "foo out @x; @x", [Call.new(nil, "foo", Out.new("@x".instance_var)), "@x".instance_var]
  it_parses "foo(out @x); @x", [Call.new(nil, "foo", Out.new("@x".instance_var)), "@x".instance_var]
  it_parses "foo out _", Call.new(nil, "foo", Out.new(Underscore.new))
  it_parses "foo z: out x; x", [Call.new(nil, "foo", named_args: [NamedArgument.new("z", Out.new("x".var))]), "x".var]

  it_parses "{1 => 2, 3 => 4}", HashLiteral.new([HashLiteral::Entry.new(1.int32, 2.int32), HashLiteral::Entry.new(3.int32, 4.int32)])
  it_parses %({A::B => 1, C::D => 2}), HashLiteral.new([HashLiteral::Entry.new(Path.new(["A", "B"]), 1.int32), HashLiteral::Entry.new(Path.new(["C", "D"]), 2.int32)])

  it_parses "{a: 1}", NamedTupleLiteral.new([NamedTupleLiteral::Entry.new("a", 1.int32)])
  it_parses "{a: 1, b: 2}", NamedTupleLiteral.new([NamedTupleLiteral::Entry.new("a", 1.int32), NamedTupleLiteral::Entry.new("b", 2.int32)])
  it_parses "{A: 1, B: 2}", NamedTupleLiteral.new([NamedTupleLiteral::Entry.new("A", 1.int32), NamedTupleLiteral::Entry.new("B", 2.int32)])

  it_parses %({"foo": 1}), NamedTupleLiteral.new([NamedTupleLiteral::Entry.new("foo", 1.int32)])
  it_parses %({"foo": 1, "bar": 2}), NamedTupleLiteral.new([NamedTupleLiteral::Entry.new("foo", 1.int32), NamedTupleLiteral::Entry.new("bar", 2.int32)])

  assert_syntax_error "{a: 1, a: 2}", "duplicated key: a"

  it_parses "{} of Int => Double", HashLiteral.new([] of HashLiteral::Entry, of: HashLiteral::Entry.new("Int".path, "Double".path))

  it_parses "require \"foo\"", Require.new("foo")
  it_parses "require \"foo\"; [1]", [Require.new("foo"), ([1.int32] of ASTNode).array]

  it_parses "case 1; when 1; 2; else; 3; end", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1; when 0, 1; 2; else; 3; end", Case.new(1.int32, [When.new([0.int32, 1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nelse\n3\nend", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nend", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)])
  it_parses "case / /; when / /; / /; else; / /; end", Case.new(regex(" "), [When.new([regex(" ")] of ASTNode, regex(" "))], regex(" "))
  it_parses "case / /\nwhen / /\n/ /\nelse\n/ /\nend", Case.new(regex(" "), [When.new([regex(" ")] of ASTNode, regex(" "))], regex(" "))

  it_parses "case 1; when 1 then 2; else; 3; end", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1; when x then 2; else; 3; end", Case.new(1.int32, [When.new(["x".call] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nend\nif a\nend", [Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)]), If.new("a".call)]
  it_parses "case\n1\nwhen 1\n2\nend\nif a\nend", [Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)]), If.new("a".call)]

  it_parses "case 1\nwhen .foo\n2\nend", Case.new(1.int32, [When.new([Call.new(ImplicitObj.new, "foo")] of ASTNode, 2.int32)])
  it_parses "case 1\nwhen .responds_to?(:foo)\n2\nend", Case.new(1.int32, [When.new([RespondsTo.new(ImplicitObj.new, "foo")] of ASTNode, 2.int32)])
  it_parses "case 1\nwhen .is_a?(T)\n2\nend", Case.new(1.int32, [When.new([IsA.new(ImplicitObj.new, "T".path)] of ASTNode, 2.int32)])
  it_parses "case 1\nwhen .as(T)\n2\nend", Case.new(1.int32, [When.new([Cast.new(ImplicitObj.new, "T".path)] of ASTNode, 2.int32)])
  it_parses "case 1\nwhen .as?(T)\n2\nend", Case.new(1.int32, [When.new([NilableCast.new(ImplicitObj.new, "T".path)] of ASTNode, 2.int32)])
  it_parses "case when 1\n2\nend", Case.new(nil, [When.new([1.int32] of ASTNode, 2.int32)])
  it_parses "case \nwhen 1\n2\nend", Case.new(nil, [When.new([1.int32] of ASTNode, 2.int32)])
  it_parses "case {1, 2}\nwhen {3, 4}\n5\nend", Case.new(TupleLiteral.new([1.int32, 2.int32] of ASTNode), [When.new([TupleLiteral.new([3.int32, 4.int32] of ASTNode)] of ASTNode, 5.int32)])
  it_parses "case {1, 2}\nwhen {3, 4}, {5, 6}\n7\nend", Case.new(TupleLiteral.new([1.int32, 2.int32] of ASTNode), [When.new([TupleLiteral.new([3.int32, 4.int32] of ASTNode), TupleLiteral.new([5.int32, 6.int32] of ASTNode)] of ASTNode, 7.int32)])
  it_parses "case {1, 2}\nwhen {.foo, .bar}\n5\nend", Case.new(TupleLiteral.new([1.int32, 2.int32] of ASTNode), [When.new([TupleLiteral.new([Call.new(ImplicitObj.new, "foo"), Call.new(ImplicitObj.new, "bar")] of ASTNode)] of ASTNode, 5.int32)])
  it_parses "case {1, 2}\nwhen foo\n5\nend", Case.new(TupleLiteral.new([1.int32, 2.int32] of ASTNode), [When.new(["foo".call] of ASTNode, 5.int32)])
  it_parses "case a\nwhen b\n1 / 2\nelse\n1 / 2\nend", Case.new("a".call, [When.new(["b".call] of ASTNode, Call.new(1.int32, "/", 2.int32))], Call.new(1.int32, "/", 2.int32))
  it_parses "case a\nwhen b\n/ /\n\nelse\n/ /\nend", Case.new("a".call, [When.new(["b".call] of ASTNode, RegexLiteral.new(StringLiteral.new(" ")))], RegexLiteral.new(StringLiteral.new(" ")))
  assert_syntax_error "case {1, 2}; when {3}; 4; end", "wrong number of tuple elements (given 1, expected 2)", 1, 19
  assert_syntax_error "case 1; end", "unexpected token: end (expecting when or else)", 1, 9

  it_parses "select\nwhen foo\n2\nend", Select.new([Select::When.new("foo".call, 2.int32)])
  it_parses "select\nwhen foo\n2\nwhen bar\n4\nend", Select.new([Select::When.new("foo".call, 2.int32), Select::When.new("bar".call, 4.int32)])
  it_parses "select\nwhen foo\n2\nelse\n3\nend", Select.new([Select::When.new("foo".call, 2.int32)], 3.int32)

  assert_syntax_error "select\nwhen 1\n2\nend", "invalid select when expression: must be an assignment or call"

  it_parses "def foo(x); end; x", [Def.new("foo", ["x".arg]), "x".call]
  it_parses "def foo; / /; end", Def.new("foo", body: regex(" "))

  it_parses "\"foo\#{bar}baz\"", StringInterpolation.new(["foo".string, "bar".call, "baz".string])
  it_parses "qux \"foo\#{bar do end}baz\"", Call.new(nil, "qux", StringInterpolation.new(["foo".string, Call.new(nil, "bar", block: Block.new), "baz".string]))
  it_parses "\"\#{1\n}\"", StringInterpolation.new([1.int32] of ASTNode)

  # When interpolating a string we don't necessarily need interpolation.
  # This is useful for example when interpolating __FILE__ and __DIR__
  it_parses "\"foo\#{\"bar\"}baz\"", "foobarbaz".string

  it_parses "lib LibFoo\nend\nif true\nend", [LibDef.new("LibFoo"), If.new(true.bool)]

  it_parses "foo(\n1\n)", Call.new(nil, "foo", 1.int32)

  it_parses "a = 1\nfoo - a", [Assign.new("a".var, 1.int32), Call.new("foo".call, "-", "a".var)]
  it_parses "a = 1\nfoo -a", [Assign.new("a".var, 1.int32), Call.new(nil, "foo", Call.new("a".var, "-"))]

  it_parses "a : Foo", TypeDeclaration.new("a".var, "Foo".path)
  it_parses "a : Foo | Int32", TypeDeclaration.new("a".var, Crystal::Union.new(["Foo".path, "Int32".path] of ASTNode))
  it_parses "@a : Foo", TypeDeclaration.new("@a".instance_var, "Foo".path)
  it_parses "@a : Foo | Int32", TypeDeclaration.new("@a".instance_var, Crystal::Union.new(["Foo".path, "Int32".path] of ASTNode))
  it_parses "@@a : Foo", TypeDeclaration.new("@@a".class_var, "Foo".path)

  it_parses "a : Foo = 1", TypeDeclaration.new("a".var, "Foo".path, 1.int32)
  it_parses "@a : Foo = 1", TypeDeclaration.new("@a".instance_var, "Foo".path, 1.int32)
  it_parses "@@a : Foo = 1", TypeDeclaration.new("@@a".class_var, "Foo".path, 1.int32)

  it_parses "a = uninitialized Foo; a", [UninitializedVar.new("a".var, "Foo".path), "a".var]
  it_parses "@a = uninitialized Foo", UninitializedVar.new("@a".instance_var, "Foo".path)
  it_parses "@@a = uninitialized Foo", UninitializedVar.new("@@a".class_var, "Foo".path)

  it_parses "()", Expressions.new([Nop.new] of ASTNode)
  it_parses "(1; 2; 3)", [1.int32, 2.int32, 3.int32] of ASTNode

  it_parses "begin; rescue; end", ExceptionHandler.new(Nop.new, [Rescue.new])
  it_parses "begin; 1; rescue; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])
  it_parses "begin; 1; ensure; 2; end", ExceptionHandler.new(1.int32, ensure: 2.int32)
  it_parses "begin\n1\nensure\n2\nend", ExceptionHandler.new(1.int32, ensure: 2.int32)
  it_parses "begin; 1; rescue Foo; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".path] of ASTNode)])
  it_parses "begin; 1; rescue ::Foo; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, [Path.global("Foo")] of ASTNode)])
  it_parses "begin; 1; rescue Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".path, "Bar".path] of ASTNode)])
  it_parses "begin; 1; rescue ::Foo | ::Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, [Path.global("Foo"), Path.global("Bar")] of ASTNode)])
  it_parses "begin; 1; rescue ex : Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".path, "Bar".path] of ASTNode, "ex")])
  it_parses "begin; 1; rescue ex : ::Foo | ::Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, [Path.global("Foo"), Path.global("Bar")] of ASTNode, "ex")])
  it_parses "begin; 1; rescue ex; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, nil, "ex")])
  it_parses "begin; 1; rescue; 2; else; 3; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)], 3.int32)
  it_parses "begin; 1; rescue ex; 2; end; ex", [ExceptionHandler.new(1.int32, [Rescue.new(2.int32, nil, "ex")]), "ex".var]

  it_parses "def foo(); 1; rescue; 2; end", Def.new("foo", body: ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))

  it_parses "1 rescue 2", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])
  it_parses "x = 1 rescue 2", Assign.new("x".var, ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))
  it_parses "x = 1 ensure 2", Assign.new("x".var, ExceptionHandler.new(1.int32, ensure: 2.int32))
  it_parses "a = 1; a rescue a", [Assign.new("a".var, 1.int32), ExceptionHandler.new("a".var, [Rescue.new("a".var)])]
  it_parses "a = 1; yield a rescue a", [Assign.new("a".var, 1.int32), ExceptionHandler.new(Yield.new(["a".var] of ASTNode), [Rescue.new("a".var)])]

  it_parses "1 ensure 2", ExceptionHandler.new(1.int32, ensure: 2.int32)
  it_parses "1 rescue 2", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])

  it_parses "foo ensure 2", ExceptionHandler.new("foo".call, ensure: 2.int32)
  it_parses "foo rescue 2", ExceptionHandler.new("foo".call, [Rescue.new(2.int32)])

  it_parses "a = 1; a ensure a", [Assign.new("a".var, 1.int32), ExceptionHandler.new("a".var, ensure: "a".var)]
  it_parses "a = 1; yield a ensure a", [Assign.new("a".var, 1.int32), ExceptionHandler.new(Yield.new(["a".var] of ASTNode), ensure: "a".var)]

  it_parses "1 <= 2 <= 3", Call.new(Call.new(1.int32, "<=", 2.int32), "<=", 3.int32)
  it_parses "1 == 2 == 3 == 4", Call.new(Call.new(Call.new(1.int32, "==", 2.int32), "==", 3.int32), "==", 4.int32)

  it_parses "-> do end", ProcLiteral.new
  it_parses "-> { }", ProcLiteral.new
  it_parses "->() { }", ProcLiteral.new
  it_parses "->(x : Int32) { }", ProcLiteral.new(Def.new("->", [Arg.new("x", restriction: "Int32".path)]))
  it_parses "->(x : Int32) { x }", ProcLiteral.new(Def.new("->", [Arg.new("x", restriction: "Int32".path)], "x".var))
  it_parses "->(x) { x }", ProcLiteral.new(Def.new("->", [Arg.new("x")], "x".var))
  it_parses "x = 1; ->{ x }", [Assign.new("x".var, 1.int32), ProcLiteral.new(Def.new("->", body: "x".var))]
  it_parses "f ->{ a do\n end\n }", Call.new(nil, "f", ProcLiteral.new(Def.new("->", body: Call.new(nil, "a", block: Block.new))))

  it_parses "->foo", ProcPointer.new(nil, "foo")
  it_parses "->Foo.foo", ProcPointer.new("Foo".path, "foo")
  it_parses "->Foo::Bar::Baz.foo", ProcPointer.new(["Foo", "Bar", "Baz"].path, "foo")
  it_parses "->foo(Int32, Float64)", ProcPointer.new(nil, "foo", ["Int32".path, "Float64".path] of ASTNode)
  it_parses "foo = 1; ->foo.bar(Int32)", [Assign.new("foo".var, 1.int32), ProcPointer.new("foo".var, "bar", ["Int32".path] of ASTNode)]
  it_parses "->foo(Void*)", ProcPointer.new(nil, "foo", ["Void".path.pointer_of] of ASTNode)
  it_parses "call ->foo", Call.new(nil, "call", ProcPointer.new(nil, "foo"))
  it_parses "[] of ->\n", ArrayLiteral.new(of: ProcNotation.new)
  it_parses "->foo=", ProcPointer.new(nil, "foo=")
  it_parses "foo = 1; ->foo.foo=", [Assign.new("foo".var, 1.int32), ProcPointer.new("foo".var, "foo=")]

  it_parses "foo.bar = {} of Int32 => Int32", Call.new("foo".call, "bar=", HashLiteral.new(of: HashLiteral::Entry.new("Int32".path, "Int32".path)))

  it_parses "alias Foo = Bar", Alias.new("Foo", "Bar".path)

  it_parses "def foo\n1\nend\nif 1\nend", [Def.new("foo", body: 1.int32), If.new(1.int32)] of ASTNode

  assert_syntax_error "1 as Bar"
  assert_syntax_error "1 as? Bar"

  it_parses "1.as Bar", Cast.new(1.int32, "Bar".path)
  it_parses "1.as(Bar)", Cast.new(1.int32, "Bar".path)
  it_parses "foo.as(Bar)", Cast.new("foo".call, "Bar".path)
  it_parses "foo.bar.as(Bar)", Cast.new(Call.new("foo".call, "bar"), "Bar".path)
  it_parses "call(foo.as Bar, Baz)", Call.new(nil, "call", args: [Cast.new("foo".call, "Bar".path), "Baz".path])

  it_parses "as(Bar)", Cast.new(Var.new("self"), "Bar".path)

  it_parses "1.as? Bar", NilableCast.new(1.int32, "Bar".path)
  it_parses "1.as?(Bar)", NilableCast.new(1.int32, "Bar".path)
  it_parses "as?(Bar)", NilableCast.new(Var.new("self"), "Bar".path)

  it_parses "typeof(1)", TypeOf.new([1.int32] of ASTNode)

  it_parses "puts ~1", Call.new(nil, "puts", Call.new(1.int32, "~"))

  it_parses "foo\n.bar", Call.new("foo".call, "bar")
  it_parses "foo\n   .bar", Call.new("foo".call, "bar")
  it_parses "foo\n\n  .bar", Call.new("foo".call, "bar")
  it_parses "foo\n  #comment\n  .bar", Call.new("foo".call, "bar")

  it_parses "{1}", TupleLiteral.new([1.int32] of ASTNode)
  it_parses "{1, 2, 3}", TupleLiteral.new([1.int32, 2.int32, 3.int32] of ASTNode)
  it_parses "{A::B}", TupleLiteral.new([Path.new(["A", "B"])] of ASTNode)
  it_parses "{\n1,\n2\n}", TupleLiteral.new([1.int32, 2.int32] of ASTNode)
  it_parses "{\n1\n}", TupleLiteral.new([1.int32] of ASTNode)
  it_parses "{\n{1}\n}", TupleLiteral.new([TupleLiteral.new([1.int32] of ASTNode)] of ASTNode)
  it_parses %({"".id}), TupleLiteral.new([Call.new("".string, "id")] of ASTNode)

  it_parses "foo { a = 1 }; a", [Call.new(nil, "foo", block: Block.new(body: Assign.new("a".var, 1.int32))), "a".call] of ASTNode

  it_parses "foo.bar(1).baz", Call.new(Call.new("foo".call, "bar", 1.int32), "baz")

  it_parses "b.c ||= 1", OpAssign.new(Call.new("b".call, "c"), "||", 1.int32)
  it_parses "b.c &&= 1", OpAssign.new(Call.new("b".call, "c"), "&&", 1.int32)

  it_parses "a = 1; class Foo; @x = a; end", [Assign.new("a".var, 1.int32), ClassDef.new("Foo".path, Assign.new("@x".instance_var, "a".call))]

  it_parses "@[Foo]", Attribute.new("Foo")
  it_parses "@[Foo()]", Attribute.new("Foo")
  it_parses "@[Foo(1)]", Attribute.new("Foo", [1.int32] of ASTNode)
  it_parses "@[Foo(\"hello\")]", Attribute.new("Foo", ["hello".string] of ASTNode)
  it_parses "@[Foo(1, foo: 2)]", Attribute.new("Foo", [1.int32] of ASTNode, [NamedArgument.new("foo", 2.int32)])
  it_parses "@[Foo(1, foo: 2\n)]", Attribute.new("Foo", [1.int32] of ASTNode, [NamedArgument.new("foo", 2.int32)])
  it_parses "@[Foo(\n1, foo: 2\n)]", Attribute.new("Foo", [1.int32] of ASTNode, [NamedArgument.new("foo", 2.int32)])

  it_parses "lib LibC\n@[Bar]; end", LibDef.new("LibC", Attribute.new("Bar"))

  it_parses "Foo(_)", Generic.new("Foo".path, [Underscore.new] of ASTNode)

  it_parses "{% if true %}\n{% end %}\n{% if true %}\n{% end %}", [MacroIf.new(true.bool, MacroLiteral.new("\n")), MacroIf.new(true.bool, MacroLiteral.new("\n"))] of ASTNode
  it_parses "fun foo : Int32; 1; end; 2", [FunDef.new("foo", return_type: "Int32".path, body: 1.int32), 2.int32]

  it_parses "[] of ->;", ArrayLiteral.new([] of ASTNode, ProcNotation.new)
  it_parses "[] of ->\n1", [ArrayLiteral.new([] of ASTNode, ProcNotation.new), 1.int32]

  it_parses "def foo(x, *y); 1; end", Def.new("foo", [Arg.new("x"), Arg.new("y")], 1.int32, splat_index: 1)
  it_parses "macro foo(x, *y);end", Macro.new("foo", [Arg.new("x"), Arg.new("y")], body: Expressions.new, splat_index: 1)

  it_parses "def foo(x = 1, *y); 1; end", Def.new("foo", [Arg.new("x", 1.int32), Arg.new("y")], 1.int32, splat_index: 1)
  it_parses "def foo(x, *y : Int32); 1; end", Def.new("foo", [Arg.new("x"), Arg.new("y", restriction: "Int32".path)], 1.int32, splat_index: 1)
  it_parses "def foo(*y : *T); 1; end", Def.new("foo", [Arg.new("y", restriction: "T".path.splat)], 1.int32, splat_index: 0)

  it_parses "foo *bar", Call.new(nil, "foo", "bar".call.splat)
  it_parses "foo(*bar)", Call.new(nil, "foo", "bar".call.splat)
  it_parses "foo x, *bar", Call.new(nil, "foo", "x".call, "bar".call.splat)
  it_parses "foo(x, *bar, *baz, y)", Call.new(nil, "foo", ["x".call, "bar".call.splat, "baz".call.splat, "y".call] of ASTNode)
  it_parses "foo.bar=(*baz)", Call.new("foo".call, "bar=", "baz".call.splat)
  it_parses "foo.bar= *baz", Call.new("foo".call, "bar=", "baz".call.splat)
  it_parses "foo.bar = (1).abs", Call.new("foo".call, "bar=", Call.new(Expressions.new([1.int32] of ASTNode), "abs"))
  it_parses "foo[*baz]", Call.new("foo".call, "[]", "baz".call.splat)
  it_parses "foo[*baz] = 1", Call.new("foo".call, "[]=", ["baz".call.splat, 1.int32] of ASTNode)

  it_parses "foo **bar", Call.new(nil, "foo", DoubleSplat.new("bar".call))
  it_parses "foo(**bar)", Call.new(nil, "foo", DoubleSplat.new("bar".call))

  it_parses "foo 1, **bar", Call.new(nil, "foo", [1.int32, DoubleSplat.new("bar".call)])
  it_parses "foo(1, **bar)", Call.new(nil, "foo", [1.int32, DoubleSplat.new("bar".call)])

  it_parses "foo 1, **bar, &block", Call.new(nil, "foo", args: [1.int32, DoubleSplat.new("bar".call)], block_arg: "block".call)
  it_parses "foo(1, **bar, &block)", Call.new(nil, "foo", args: [1.int32, DoubleSplat.new("bar".call)], block_arg: "block".call)

  assert_syntax_error "foo **bar, 1", "argument not allowed after double splat"
  assert_syntax_error "foo(**bar, 1)", "argument not allowed after double splat"

  assert_syntax_error "foo **bar, *x", "splat not allowed after double splat"
  assert_syntax_error "foo(**bar, *x)", "splat not allowed after double splat"

  assert_syntax_error "foo **bar, out x", "out argument not allowed after double splat"
  assert_syntax_error "foo(**bar, out x)", "out argument not allowed after double splat"

  it_parses "private def foo; end", VisibilityModifier.new(Visibility::Private, Def.new("foo"))
  it_parses "protected def foo; end", VisibilityModifier.new(Visibility::Protected, Def.new("foo"))

  it_parses "`foo`", Call.new(nil, "`", "foo".string)
  it_parses "`foo\#{1}bar`", Call.new(nil, "`", StringInterpolation.new(["foo".string, 1.int32, "bar".string] of ASTNode))
  it_parses "`foo\\``", Call.new(nil, "`", "foo`".string)
  it_parses "%x(`which(foo)`)", Call.new(nil, "`", "`which(foo)`".string)

  it_parses "def `(cmd); 1; end", Def.new("`", ["cmd".arg], 1.int32)

  it_parses "def foo(bar = 1\n); 2; end", Def.new("foo", [Arg.new("bar", default_value: 1.int32)], 2.int32)

  it_parses "Set {1, 2, 3}", ArrayLiteral.new([1.int32, 2.int32, 3.int32] of ASTNode, name: "Set".path)
  it_parses "Set(Int32) {1, 2, 3}", ArrayLiteral.new([1.int32, 2.int32, 3.int32] of ASTNode, name: Generic.new("Set".path, ["Int32".path] of ASTNode))

  it_parses "foo(Bar) { 1 }", Call.new(nil, "foo", args: ["Bar".path] of ASTNode, block: Block.new(body: 1.int32))
  it_parses "foo Bar { 1 }", Call.new(nil, "foo", args: [ArrayLiteral.new([1.int32] of ASTNode, name: "Bar".path)] of ASTNode)
  it_parses "foo(Bar { 1 })", Call.new(nil, "foo", args: [ArrayLiteral.new([1.int32] of ASTNode, name: "Bar".path)] of ASTNode)

  it_parses "\n\n__LINE__", 3.int32
  it_parses "__FILE__", "/foo/bar/baz.cr".string
  it_parses "__DIR__", "/foo/bar".string

  it_parses "def foo(x = __LINE__); end", Def.new("foo", args: [Arg.new("x", default_value: MagicConstant.new(:__LINE__))])
  it_parses "def foo(x = __FILE__); end", Def.new("foo", args: [Arg.new("x", default_value: MagicConstant.new(:__FILE__))])
  it_parses "def foo(x = __DIR__); end", Def.new("foo", args: [Arg.new("x", default_value: MagicConstant.new(:__DIR__))])

  it_parses "macro foo(x = __LINE__);end", Macro.new("foo", body: Expressions.new, args: [Arg.new("x", default_value: MagicConstant.new(:__LINE__))])

  it_parses "1 \\\n + 2", Call.new(1.int32, "+", 2.int32)
  it_parses "1\\\n + 2", Call.new(1.int32, "+", 2.int32)

  it_parses %("hello " \\\n "world"), StringLiteral.new("hello world")
  it_parses %("hello "\\\n"world"), StringLiteral.new("hello world")
  it_parses %("hello \#{1}" \\\n "\#{2} world"), StringInterpolation.new(["hello ".string, 1.int32, 2.int32, " world".string] of ASTNode)
  it_parses "<<-HERE\nHello, mom! I am HERE.\nHER dress is beautiful.\nHE is OK.\n  HERESY\nHERE", "Hello, mom! I am HERE.\nHER dress is beautiful.\nHE is OK.\n  HERESY".string
  it_parses "<<-HERE\n   One\n  Zero\n  HERE", " One\nZero".string
  it_parses "<<-HERE\n   One \\n Two\n  Zero\n  HERE", " One \n Two\nZero".string
  it_parses "<<-HERE\n   One\n\n  Zero\n  HERE", " One\n\nZero".string
  it_parses "<<-HERE\n   One\n \n  Zero\n  HERE", " One\n\nZero".string
  it_parses "<<-HERE\n   \#{1}One\n  \#{2}Zero\n  HERE", StringInterpolation.new([" ".string, 1.int32, "One\n".string, 2.int32, "Zero".string] of ASTNode)
  it_parses "<<-HERE\n  foo\#{1}bar\n   baz\n  HERE", StringInterpolation.new(["foo".string, 1.int32, "bar\n baz".string] of ASTNode)
  it_parses "<<-HERE\r\n   One\r\n  Zero\r\n  HERE", " One\r\nZero".string
  it_parses "<<-HERE\r\n   One\r\n  Zero\r\n  HERE\r\n", " One\r\nZero".string
  it_parses "<<-SOME\n  Sa\n  Se\n  SOME", "Sa\nSe".string
  it_parses "<<-HERE\n  \#{1} \#{2}\n  HERE", StringInterpolation.new([1.int32, " ".string, 2.int32] of ASTNode)
  it_parses "<<-HERE\n  \#{1} \\n \#{2}\n  HERE", StringInterpolation.new([1.int32, " \n ".string, 2.int32] of ASTNode)
  assert_syntax_error "<<-HERE\n   One\nwrong\n  Zero\n  HERE", "heredoc line must have an indent greater or equal than 2", 3, 1
  assert_syntax_error "<<-HERE\n   One\n wrong\n  Zero\n  HERE", "heredoc line must have an indent greater or equal than 2", 3, 1
  assert_syntax_error "<<-HERE\n   One\n \#{1}\n  Zero\n  HERE", "heredoc line must have an indent greater or equal than 2", 3, 1
  assert_syntax_error "<<-HERE\n   One\n  \#{1}\n wrong\n  HERE", "heredoc line must have an indent greater or equal than 2", 4, 1
  assert_syntax_error "<<-HERE\n   One\n  \#{1}\n wrong\#{1}\n  HERE", "heredoc line must have an indent greater or equal than 2", 4, 1
  assert_syntax_error "<<-HERE\n One\n  \#{1}\n  HERE", "heredoc line must have an indent greater or equal than 2", 2, 1
  assert_syntax_error %("foo" "bar")

  it_parses "<<-'HERE'\n  hello \\n world\n  \#{1}\n  HERE", StringLiteral.new("hello \\n world\n\#{1}")
  assert_syntax_error "<<-'HERE\n", "expecting closing single quote"

  it_parses "<<-FOO\n1\nFOO.bar", Call.new("1".string, "bar")
  it_parses "<<-FOO\n1\nFOO + 2", Call.new("1".string, "+", 2.int32)

  it_parses "<<-FOO\n\t1\n\tFOO", StringLiteral.new("1")
  it_parses "<<-FOO\n \t1\n \tFOO", StringLiteral.new("1")
  it_parses "<<-FOO\n \t 1\n \t FOO", StringLiteral.new("1")
  it_parses "<<-FOO\n\t 1\n\t FOO", StringLiteral.new("1")

  it_parses "enum Foo; A\nB, C\nD = 1; end", EnumDef.new("Foo".path, [Arg.new("A"), Arg.new("B"), Arg.new("C"), Arg.new("D", 1.int32)] of ASTNode)
  it_parses "enum Foo; A = 1, B; end", EnumDef.new("Foo".path, [Arg.new("A", 1.int32), Arg.new("B")] of ASTNode)
  it_parses "enum Foo : UInt16; end", EnumDef.new("Foo".path, base_type: "UInt16".path)
  it_parses "enum Foo; def foo; 1; end; end", EnumDef.new("Foo".path, [Def.new("foo", body: 1.int32)] of ASTNode)
  it_parses "enum Foo; A = 1\ndef foo; 1; end; end", EnumDef.new("Foo".path, [Arg.new("A", 1.int32), Def.new("foo", body: 1.int32)] of ASTNode)
  it_parses "enum Foo; A = 1\ndef foo; 1; end\ndef bar; 2; end\nend", EnumDef.new("Foo".path, [Arg.new("A", 1.int32), Def.new("foo", body: 1.int32), Def.new("bar", body: 2.int32)] of ASTNode)
  it_parses "enum Foo; A = 1\ndef self.foo; 1; end\nend", EnumDef.new("Foo".path, [Arg.new("A", 1.int32), Def.new("foo", receiver: "self".var, body: 1.int32)] of ASTNode)
  it_parses "enum Foo::Bar; A = 1; end", EnumDef.new(Path.new(["Foo", "Bar"]), [Arg.new("A", 1.int32)] of ASTNode)

  it_parses "enum Foo; @@foo = 1\n A \n end", EnumDef.new("Foo".path, [Assign.new("@@foo".class_var, 1.int32), Arg.new("A")] of ASTNode)

  it_parses "enum Foo; private def foo; 1; end; end", EnumDef.new("Foo".path, [VisibilityModifier.new(Visibility::Private, Def.new("foo", body: 1.int32))] of ASTNode)
  it_parses "enum Foo; protected def foo; 1; end; end", EnumDef.new("Foo".path, [VisibilityModifier.new(Visibility::Protected, Def.new("foo", body: 1.int32))] of ASTNode)

  it_parses "enum Foo; {{1}}; end", EnumDef.new("Foo".path, [MacroExpression.new(1.int32)] of ASTNode)
  it_parses "enum Foo; {% if 1 %}2{% end %}; end", EnumDef.new("Foo".path, [MacroIf.new(1.int32, MacroLiteral.new("2"))] of ASTNode)

  it_parses "enum Foo; macro foo;end; end", EnumDef.new("Foo".path, [Macro.new("foo", [] of Arg, Expressions.new)] of ASTNode)

  it_parses "1.[](2)", Call.new(1.int32, "[]", 2.int32)
  it_parses "1.[]?(2)", Call.new(1.int32, "[]?", 2.int32)
  it_parses "1.[]=(2, 3)", Call.new(1.int32, "[]=", 2.int32, 3.int32)

  it_parses "a @b-1\nc", [Call.new(nil, "a", Call.new("@b".instance_var, "-", 1.int32)), "c".call] of ASTNode
  it_parses "4./(2)", Call.new(4.int32, "/", 2.int32)
  it_parses "foo[\n1\n]", Call.new("foo".call, "[]", 1.int32)
  it_parses "foo[\nfoo[\n1\n]\n]", Call.new("foo".call, "[]", Call.new("foo".call, "[]", 1.int32))

  it_parses "if (\ntrue\n)\n1\nend", If.new(Expressions.new([true.bool] of ASTNode), 1.int32)

  it_parses "my_def def foo\nloop do\nend\nend", Call.new(nil, "my_def", Def.new("foo", body: Call.new(nil, "loop", block: Block.new)))

  it_parses "foo(*{1})", Call.new(nil, "foo", Splat.new(TupleLiteral.new([1.int32] of ASTNode)))
  it_parses "foo *{1}", Call.new(nil, "foo", Splat.new(TupleLiteral.new([1.int32] of ASTNode)))

  it_parses "a.b/2", Call.new(Call.new("a".call, "b"), "/", 2.int32)
  it_parses "a.b /2/", Call.new("a".call, "b", regex("2"))
  it_parses "a.b / 2", Call.new(Call.new("a".call, "b"), "/", 2.int32)
  it_parses "a/b", Call.new("a".call, "/", "b".call)
  it_parses "T/1", Call.new("T".path, "/", 1.int32)
  it_parses "T::U/1", Call.new(Path.new(%w(T U)), "/", 1.int32)
  it_parses "::T/1", Call.new(Path.global("T"), "/", 1.int32)

  it_parses %(asm("nop" \n)), Asm.new("nop")
  it_parses %(asm("nop" : : )), Asm.new("nop")
  it_parses %(asm("nop" ::)), Asm.new("nop")
  it_parses %(asm("nop" : "a"(0))), Asm.new("nop", AsmOperand.new("a", 0.int32))
  it_parses %(asm("nop" : "a"(0) : "b"(1))), Asm.new("nop", AsmOperand.new("a", 0.int32), [AsmOperand.new("b", 1.int32)])
  it_parses %(asm("nop" : "a"(0) : "b"(1), "c"(2))), Asm.new("nop", AsmOperand.new("a", 0.int32), [AsmOperand.new("b", 1.int32), AsmOperand.new("c", 2.int32)])
  it_parses %(asm("nop" :: "b"(1), "c"(2))), Asm.new("nop", inputs: [AsmOperand.new("b", 1.int32), AsmOperand.new("c", 2.int32)])
  it_parses %(asm(\n"nop"\n:\n"a"(0)\n:\n"b"(1),\n"c"(2)\n)), Asm.new("nop", AsmOperand.new("a", 0.int32), [AsmOperand.new("b", 1.int32), AsmOperand.new("c", 2.int32)])
  it_parses %(asm("nop" :: "b"(1), "c"(2) : "eax", "ebx" : "volatile", "alignstack", "intel")), Asm.new("nop", inputs: [AsmOperand.new("b", 1.int32), AsmOperand.new("c", 2.int32)], clobbers: %w(eax ebx), volatile: true, alignstack: true, intel: true)
  it_parses %(asm("nop" :: "b"(1), "c"(2) : "eax", "ebx"\n: "volatile", "alignstack"\n,\n"intel"\n)), Asm.new("nop", inputs: [AsmOperand.new("b", 1.int32), AsmOperand.new("c", 2.int32)], clobbers: %w(eax ebx), volatile: true, alignstack: true, intel: true)
  it_parses %(asm("nop" :::: "volatile")), Asm.new("nop", volatile: true)

  assert_syntax_error %q(asm("nop" ::: "#{foo}")), "interpolation not allowed in asm clobber"
  assert_syntax_error %q(asm("nop" :::: "#{volatile}")), "interpolation not allowed in asm option"

  it_parses "foo begin\nbar do\nend\nend", Call.new(nil, "foo", Expressions.new([Call.new(nil, "bar", block: Block.new)] of ASTNode))
  it_parses "foo 1.bar do\nend", Call.new(nil, "foo", args: [Call.new(1.int32, "bar")] of ASTNode, block: Block.new)
  it_parses "return 1.bar do\nend", Return.new(Call.new(1.int32, "bar", block: Block.new))

  %w(begin nil true false yield with abstract def macro require case if unless include extend class struct module enum while
    until return next break lib fun alias pointerof sizeof instance_sizeof typeof private protected asm end do else elsif when rescue ensure).each do |keyword|
    it_parses "#{keyword} : Int32", TypeDeclaration.new(keyword.var, "Int32".path)
    it_parses "property #{keyword} : Int32", Call.new(nil, "property", TypeDeclaration.new(keyword.var, "Int32".path))
  end

  it_parses "call(foo : A, end : B)", Call.new(nil, "call", [TypeDeclaration.new("foo".var, "A".path), TypeDeclaration.new("end".var, "B".path)] of ASTNode)
  it_parses "call foo : A, end : B", Call.new(nil, "call", [TypeDeclaration.new("foo".var, "A".path), TypeDeclaration.new("end".var, "B".path)] of ASTNode)

  it_parses "case :foo; when :bar; 2; end", Case.new("foo".symbol, [When.new(["bar".symbol] of ASTNode, 2.int32)])

  it_parses "Foo.foo(count: 3).bar { }", Call.new(Call.new("Foo".path, "foo", named_args: [NamedArgument.new("count", 3.int32)]), "bar", block: Block.new)

  it_parses %(
    class Foo
      def bar
        print as Foo
      end
    end
  ), ClassDef.new("Foo".path, Def.new("bar", body: Call.new(nil, "print", Cast.new(Var.new("self"), "Foo".path))))

  assert_syntax_error "a = a", "can't use variable name 'a' inside assignment to variable 'a'"

  assert_syntax_error "{{ {{ 1 }} }}", "can't nest macro expressions"
  assert_syntax_error "{{ {% begin %} }}", "can't nest macro expressions"

  it_parses "Foo?", Crystal::Generic.new(Path.global("Union"), ["Foo".path, Path.global("Nil")] of ASTNode)
  it_parses "Foo::Bar?", Crystal::Generic.new(Path.global("Union"), [Path.new(%w(Foo Bar)), Path.global("Nil")] of ASTNode)
  it_parses "Foo(T)?", Crystal::Generic.new(Path.global("Union"), [Generic.new("Foo".path, ["T".path] of ASTNode), Path.global("Nil")] of ASTNode)
  it_parses "Foo??", Crystal::Generic.new(Path.global("Union"), [
    Crystal::Generic.new(Path.global("Union"), ["Foo".path, Path.global("Nil")] of ASTNode),
    Path.global("Nil"),
  ] of ASTNode)

  it_parses "{1 => 2 / 3}", HashLiteral.new([HashLiteral::Entry.new(1.int32, Call.new(2.int32, "/", 3.int32))])
  it_parses "a { |x| x } / b", Call.new(Call.new(nil, "a", block: Block.new(args: ["x".var], body: "x".var)), "/", "b".call)

  it_parses "1 if /x/", If.new(RegexLiteral.new("x".string), 1.int32)

  it_parses "foo bar.baz(1) do\nend", Call.new(nil, "foo", args: [Call.new("bar".call, "baz", 1.int32)] of ASTNode, block: Block.new)

  it_parses "1 rescue 2 if 3", If.new(3.int32, ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))
  it_parses "1 ensure 2 if 3", If.new(3.int32, ExceptionHandler.new(1.int32, ensure: 2.int32))

  it_parses "yield foo do\nend", Yield.new([Call.new(nil, "foo", block: Block.new)] of ASTNode)

  it_parses "x.y=(1).to_s", Call.new("x".call, "y=", Call.new(Expressions.new([1.int32] of ASTNode), "to_s"))

  it_parses "1 ** -x", Call.new(1.int32, "**", Call.new("x".call, "-"))

  it_parses "foo.Bar", Call.new("foo".call, "Bar")

  assert_syntax_error "return do\nend", "unexpected token: do"

  %w(def macro class struct module fun alias abstract include extend lib).each do |keyword|
    assert_syntax_error "def foo\n#{keyword}\nend"
  end

  assert_syntax_error "def foo(x = 1, y); end",
    "argument must have a default value"

  assert_syntax_error " [1, 2, 3 end"
  assert_syntax_error " {1 => end"

  assert_syntax_error " {1, 2, 3 end"
  assert_syntax_error " (1, 2, 3 end",
    "unterminated parenthesized expression", 1, 2

  assert_syntax_error "foo(1, 2, 3 end",
    "expecting token ')', not 'end'", 1, 13

  assert_syntax_error "foo(foo(&.block)",
    "expecting token ')', not 'EOF'", 1, 17

  assert_syntax_error "case when .foo? then 1; end"
  assert_syntax_error "macro foo;{%end};end"
  assert_syntax_error "foo {1, 2}", "unexpected token: ,"
  assert_syntax_error "pointerof(self)", "can't take pointerof(self)"
  assert_syntax_error "def foo 1; end"

  assert_syntax_error %<{"x": [] of Int32,\n}\n1.foo(>, "unterminated call", 3, 6

  assert_syntax_error "def foo x y; end", "parentheses are mandatory for def arguments"
  assert_syntax_error "macro foo(x y z); end"
  assert_syntax_error "macro foo x y; end", "parentheses are mandatory for macro arguments"
  assert_syntax_error "macro foo *y;end", "parentheses are mandatory for macro arguments"
  assert_syntax_error %(macro foo x; 1 + 2; end), "parentheses are mandatory for macro arguments"
  assert_syntax_error %(macro foo x\n 1 + 2; end), "parentheses are mandatory for macro arguments"

  assert_syntax_error "1 2", "unexpected token: 2"
  assert_syntax_error "macro foo(*x, *y); end", "unexpected token: *"

  assert_syntax_error "foo x: 1, x: 1", "duplicated named argument: x", 1, 11
  assert_syntax_error "def foo(x, x); end", "duplicated argument name: x", 1, 12
  assert_syntax_error "class Foo(T, T); end", "duplicated type var name: T", 1, 14
  assert_syntax_error "->(x : Int32, x : Int32) {}", "duplicated argument name: x", 1, 15
  assert_syntax_error "foo { |x, x| }", "duplicated block argument name: x", 1, 11
  assert_syntax_error "foo { |x, (x)| }", "duplicated block argument name: x", 1, 12
  assert_syntax_error "foo { |(x, x)| }", "duplicated block argument name: x", 1, 12

  assert_syntax_error "def foo(*x, **x); end", "duplicated argument name: x"
  assert_syntax_error "def foo(*x, &x); end", "duplicated argument name: x"
  assert_syntax_error "def foo(**x, &x); end", "duplicated argument name: x"
  assert_syntax_error "def foo(x, **x); end", "duplicated argument name: x"

  assert_syntax_error "Set {1, 2, 3} of Int32"
  assert_syntax_error "Hash {foo: 1} of Int32 => Int32"
  assert_syntax_error "case foo; end"
  assert_syntax_error "enum Foo < UInt16; end"
  assert_syntax_error "foo(1 2)"
  assert_syntax_error %(foo("bar" "baz"))

  assert_syntax_error "@:Foo"

  assert_syntax_error "false foo"
  assert_syntax_error "nil foo"
  assert_syntax_error "'a' foo"
  assert_syntax_error %("hello" foo)
  assert_syntax_error %(:bar foo)
  assert_syntax_error "1 foo"
  assert_syntax_error "1 then"
  assert_syntax_error "return 1 foo"
  assert_syntax_error "return false foo"

  assert_syntax_error "a = 1; b = 2; a, b += 1, 2"

  assert_syntax_error "lib LibC\n$Errno : Int32\nend", "external variables must start with lowercase, use for example `$errno = Errno : Int32`"

  assert_syntax_error "a += 1",
    "'+=' before definition of 'a'"
  assert_syntax_error "self = 1",
    "can't change the value of self"
  assert_syntax_error "self += 1",
    "can't change the value of self"
  assert_syntax_error "FOO, BAR = 1, 2",
    "Multiple assignment is not allowed for constants"
  assert_syntax_error "self, x = 1, 2",
    "can't change the value of self"
  assert_syntax_error "x, self = 1, 2",
    "can't change the value of self"

  assert_syntax_error "macro foo(x : Int32); end"

  assert_syntax_error "/foo)/", "invalid regex"
  assert_syntax_error "def =\nend"
  assert_syntax_error "def foo; A = 1; end", "dynamic constant assignment. Constants can only be declared at the top level or inside other types."
  assert_syntax_error "{1, ->{ |x| x } }", "unexpected token '|'"
  assert_syntax_error "{1, ->do\n|x| x\end }", "unexpected token '|'"

  assert_syntax_error "1 while 3", "trailing `while` is not supported"
  assert_syntax_error "1 until 3", "trailing `until` is not supported"
  assert_syntax_error "x++", "postfix increment is not supported, use `exp += 1`"
  assert_syntax_error "x--", "postfix decrement is not supported, use `exp -= 1`"
  assert_syntax_error "if 1 == 1 a; end", "unexpected token"
  assert_syntax_error "unless 1 == 1 a; end", "unexpected token"
  assert_syntax_error "while 1 == 1 a; end", "unexpected token"
  assert_syntax_error "case 1 == 1 a; when 2; end", "unexpected token"
  assert_syntax_error "case 1 == 1; when 2 a; end", "unexpected token"

  assert_syntax_error %(class Foo; require "bar"; end), "can't require inside type declarations"
  assert_syntax_error %(module Foo; require "bar"; end), "can't require inside type declarations"
  assert_syntax_error %(def foo; require "bar"; end), "can't require inside def"

  assert_syntax_error "def foo(x: Int32); end", "space required before colon in type restriction"
  assert_syntax_error "def foo(x :Int32); end", "space required after colon in type restriction"

  assert_syntax_error "def f end", "unexpected token: end (expected ';' or newline)"

  assert_syntax_error %([\n"foo"\n"bar"\n])
  it_parses "[\n1\n]", ArrayLiteral.new([1.int32] of ASTNode)
  it_parses "[\n1,2\n]", ArrayLiteral.new([1.int32, 2.int32] of ASTNode)

  assert_syntax_error %({\n1 => 2\n3 => 4\n})
  assert_syntax_error %({\n1 => 2, 3 => 4\n5 => 6})

  assert_syntax_error %({\n"foo"\n"bar"\n})

  assert_syntax_error %(
    lib LibFoo
      fun foo(x : Int32
            y : Float64)
    end
    )

  assert_syntax_error %(
    if 1
      foo 1,
    end
    ), "invalid trailing comma in call"

  assert_syntax_error "foo 1,", "invalid trailing comma in call"
  assert_syntax_error "def foo:String\nend", "a space is mandatory between ':' and return type"
  assert_syntax_error "def foo :String\nend", "a space is mandatory between ':' and return type"
  assert_syntax_error "def foo():String\nend", "a space is mandatory between ':' and return type"
  assert_syntax_error "def foo() :String\nend", "a space is mandatory between ':' and return type"

  assert_syntax_error "foo.responds_to?"

  assert_syntax_error "foo :: Foo"
  assert_syntax_error "@foo :: Foo"
  assert_syntax_error "@@foo :: Foo"
  assert_syntax_error "$foo :: Foo"

  assert_syntax_error "def foo(var : Foo+); end"

  %w(&& || !).each do |name|
    assert_syntax_error "foo.#{name}"
    assert_syntax_error "foo.#{name}()"
    assert_syntax_error "foo &.#{name}"
    assert_syntax_error "foo &.#{name}()"
  end

  %w(! is_a? as as? responds_to? nil?).each do |name|
    assert_syntax_error "def #{name}; end", "'#{name}' is a pseudo-method and can't be redefined"
    assert_syntax_error "def self.#{name}; end", "'#{name}' is a pseudo-method and can't be redefined"
    assert_syntax_error "macro #{name}; end", "'#{name}' is a pseudo-method and can't be redefined"
  end

  assert_syntax_error "Foo{one: :two, three: :four}", "can't use named tuple syntax for Hash-like literal"
  assert_syntax_error "{one: :two, three: :four} of Symbol => Symbol"
  assert_syntax_error %(Hash{"foo": 1}), "can't use named tuple syntax for Hash-like literal"
  assert_syntax_error %(Hash{"foo": 1, "bar": 2}), "can't use named tuple syntax for Hash-like literal"

  assert_syntax_error "{foo: 1\nbar: 2}"
  assert_syntax_error "{foo: 1, bar: 2\nbaz: 3}"

  assert_syntax_error "'''", "invalid empty char literal"

  assert_syntax_error "def foo(*args = 1); end", "splat argument can't have default value"
  assert_syntax_error "def foo(**args = 1); end", "double splat argument can't have default value"

  assert_syntax_error "require 1", "expected string literal for require"
  assert_syntax_error %(def foo("bar \#{1} qux" y); y; end), "interpolation not allowed in external name"

  assert_syntax_error "def Foo(Int32).bar;end"

  assert_syntax_error "[1 1]"
  assert_syntax_error "{1 => 2 3 => 4}"
  assert_syntax_error "{1 => 2, 3 => 4 5 => 6}"
  assert_syntax_error "{a: 1 b: 2}"
  assert_syntax_error "{a: 1, b: 2 c: 3}"
  assert_syntax_error "{1 2}"
  assert_syntax_error "{1, 2 3}"
  assert_syntax_error "(1, 2 3)"
  assert_syntax_error "Foo(T U)"
  assert_syntax_error "Foo(T, U V)"
  assert_syntax_error "class Foo(T U)"
  assert_syntax_error "class Foo(T, U V)"
  assert_syntax_error "->(x y) { }"
  assert_syntax_error "->(x, y z) { }"

  assert_syntax_error "x[1:-2]"

  assert_syntax_error "1 ? : 2 : 3"

  assert_syntax_error %(def foo("bar");end), "expected argument internal name"

  describe "end locations" do
    assert_end_location "nil"
    assert_end_location "false"
    assert_end_location "123"
    assert_end_location "123.45"
    assert_end_location "'a'"
    assert_end_location ":foo"
    assert_end_location %("hello")
    assert_end_location "[1, 2]"
    assert_end_location "[] of Int32"
    assert_end_location "{a: 1}"
    assert_end_location "{} of Int32 => String"
    assert_end_location "1..3"
    assert_end_location "/foo/"
    assert_end_location "{1, 2}"
    assert_end_location "foo"
    assert_end_location "foo(1, 2)"
    assert_end_location "foo 1, 2"
    assert_end_location "Foo"
    assert_end_location "Foo(A)"
    assert_end_location "if 1; else; 2; end"
    assert_end_location "if 1; elseif; 2; end"
    assert_end_location "unless 1; 2; end"
    assert_end_location "a = 123"
    assert_end_location "a, b = 1, 2"
    assert_end_location "@foo"
    assert_end_location "foo.@foo"
    assert_end_location "@@foo"
    assert_end_location "a && b"
    assert_end_location "a || b"
    assert_end_location "def foo; end"
    assert_end_location "def foo; 1; end"
    assert_end_location "def foo; rescue ex; end"
    assert_end_location "abstract def foo"
    assert_end_location "abstract def foo : Int32"
    assert_end_location "begin; 1; end"
    assert_end_location "class Foo; end"
    assert_end_location "struct Foo; end"
    assert_end_location "module Foo; end"
    assert_end_location "->{ }"
    assert_end_location "macro foo;end"
    assert_end_location "macro foo; 123; end"
    assert_end_location "!foo"
    assert_end_location "pointerof(@foo)"
    assert_end_location "sizeof(Foo)"
    assert_end_location "typeof(1)"
    assert_end_location "1 if 2"
    assert_end_location "while 1; end"
    assert_end_location "return"
    assert_end_location "return 1"
    assert_end_location "yield"
    assert_end_location "yield 1"
    assert_end_location "include Foo"
    assert_end_location "extend Foo"
    assert_end_location "1.as(Int32)"
    assert_end_location "puts obj.foo"

    assert_syntax_error %({"a" : 1}), "space not allowed between named argument name and ':'"
    assert_syntax_error %({"a": 1, "b" : 2}), "space not allowed between named argument name and ':'"

    assert_syntax_error "case x; when nil; 2; when nil; end", "duplicate when nil in case"
    assert_syntax_error "case x; when true; 2; when true; end", "duplicate when true in case"
    assert_syntax_error "case x; when 1; 2; when 1; end", "duplicate when 1 in case"
    assert_syntax_error "case x; when 'a'; 2; when 'a'; end", "duplicate when 'a' in case"
    assert_syntax_error %(case x; when "a"; 2; when "a"; end), %(duplicate when "a" in case)
    assert_syntax_error %(case x; when :a; 2; when :a; end), "duplicate when :a in case"
    assert_syntax_error %(case x; when {1, 2}; 2; when {1, 2}; end), "duplicate when {1, 2} in case"
    assert_syntax_error %(case x; when [1, 2]; 2; when [1, 2]; end), "duplicate when [1, 2] in case"
    assert_syntax_error %(case x; when 1..2; 2; when 1..2; end), "duplicate when 1..2 in case"
    assert_syntax_error %(case x; when /x/; 2; when /x/; end), "duplicate when /x/ in case"
    assert_syntax_error %(case x; when X; 2; when X; end), "duplicate when X in case"

    it "gets corrects of ~" do
      node = Parser.parse("\n  ~1")
      loc = node.location.not_nil!
      loc.line_number.should eq(2)
      loc.column_number.should eq(3)
    end

    it "gets corrects end location for var" do
      parser = Parser.new("foo = 1\nfoo; 1")
      node = parser.parse.as(Expressions).expressions[1]
      end_loc = node.end_location.not_nil!
      end_loc.line_number.should eq(2)
      end_loc.column_number.should eq(3)
    end

    it "gets corrects end location for block with { ... }" do
      parser = Parser.new("foo { 1 + 2 }; 1")
      node = parser.parse.as(Expressions).expressions[0].as(Call)
      block = node.block.not_nil!
      end_loc = block.end_location.not_nil!
      end_loc.line_number.should eq(1)
      end_loc.column_number.should eq(13)
      node.end_location.should eq(end_loc)
    end

    it "gets corrects end location for block with do ... end" do
      parser = Parser.new("foo do\n  1 + 2\nend; 1")
      node = parser.parse.as(Expressions).expressions[0].as(Call)
      block = node.block.not_nil!
      end_loc = block.end_location.not_nil!
      end_loc.line_number.should eq(3)
      end_loc.column_number.should eq(3)
      node.end_location.should eq(end_loc)
    end

    it "gets correct location after macro with yield" do
      parser = Parser.new(%(
        macro foo
          yield
        end

        1 + 'a'
        ))
      node = parser.parse.as(Expressions).expressions[1]
      loc = node.location.not_nil!
      loc.line_number.should eq(6)
    end

    it "gets correct location with \r\n (#1558)" do
      nodes = Parser.parse("class Foo\r\nend\r\n\r\n1").as(Expressions)
      loc = nodes.last.location.not_nil!
      loc.line_number.should eq(4)
      loc.column_number.should eq(1)
    end

    it "sets location of enum method" do
      parser = Parser.new("enum Foo; A; def bar; end; end")
      node = parser.parse.as(EnumDef).members[1].as(Def)
      loc = node.location.not_nil!
      loc.line_number.should eq(1)
      loc.column_number.should eq(14)
    end

    it "gets correct location after macro with yield" do
      parser = Parser.new(%(\n  1 ? 2 : 3))
      node = parser.parse
      loc = node.location.not_nil!
      loc.line_number.should eq(2)
      loc.column_number.should eq(3)
    end
  end
end
