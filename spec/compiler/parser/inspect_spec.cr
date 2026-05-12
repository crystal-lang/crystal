require "../../support/syntax"

private def expect_inspect(source, expected = source, file = __FILE__, line = __LINE__)
  it "inspects #{source.inspect}", file, line do
    node = Parser.new(source).parse
    node.inspect.should eq(expected), file: file, line: line
  end
end

describe "ASTNode#inspect" do
  expect_inspect %q{[] of T}, %(ArrayLiteral[of: Path["T"]])
  expect_inspect %q{([] of T).foo}, %(Call[Expressions.paren(ArrayLiteral[of: Path["T"]]), "foo"])
  expect_inspect %q{({} of K => V).foo}, <<-CRYSTAL
  Call[
    Expressions.paren(HashLiteral[of: HashLiteral::Entry[Path["K"], Path["V"]]]),
    "foo"
  ]
  CRYSTAL
  expect_inspect %q{foo(bar)}, %(Call["foo", [Call["bar"]]])
  expect_inspect %q{(~1).foo}, %(Call[Expressions.paren(Call[NumberLiteral["1", :i32], "~"]), "foo"])
  expect_inspect %q{1 && (a = 2)}, <<-CRYSTAL
  And[
    NumberLiteral["1", :i32],
    Expressions.paren(Assign[Var["a"], NumberLiteral["2", :i32]])
  ]
  CRYSTAL
  expect_inspect %q{(a = 2) && 1}, <<-CRYSTAL
  And[
    Expressions.paren(Assign[Var["a"], NumberLiteral["2", :i32]]),
    NumberLiteral["1", :i32]
  ]
  CRYSTAL
  expect_inspect %q{foo(a.as(Int32))}, %(Call["foo", [Cast[Call["a"], Path["Int32"]]]])
  expect_inspect %q{(1 + 2).as(Int32)}, <<-CRYSTAL
  Cast[
    Expressions.paren(
      Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
    ),
    Path["Int32"]
  ]
  CRYSTAL
  expect_inspect %q{a.as?(Int32)}, %(NilableCast[Call["a"], Path["Int32"]])
  expect_inspect %q{(1 + 2).as?(Int32)}, <<-CRYSTAL
  NilableCast[
    Expressions.paren(
      Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
    ),
    Path["Int32"]
  ]
  CRYSTAL
  expect_inspect %q{@foo.bar}, %(Call[InstanceVar["@foo"], "bar"])
  expect_inspect %(:foo), %(SymbolLiteral["foo"])
  expect_inspect %(:"{"), %(SymbolLiteral["{"])
  expect_inspect %(%r()), %(RegexLiteral[StringLiteral[""]])
  expect_inspect %(%r()imx), <<-CRYSTAL
  RegexLiteral[
    StringLiteral[""],
    options: Regex::Options[IGNORE_CASE, MULTILINE, EXTENDED]
  ]
  CRYSTAL
  expect_inspect %(/hello world/), %(RegexLiteral[StringLiteral["hello world"]])
  expect_inspect %(/hello world/imx), <<-CRYSTAL
  RegexLiteral[
    StringLiteral["hello world"],
    options: Regex::Options[IGNORE_CASE, MULTILINE, EXTENDED]
  ]
  CRYSTAL
  expect_inspect %(/\\s/), %(RegexLiteral[StringLiteral["\\\\s"]])
  expect_inspect %(/\\?/), %(RegexLiteral[StringLiteral["\\\\?"]])
  expect_inspect %(/\\(group\\)/), %(RegexLiteral[StringLiteral["\\\\(group\\\\)"]])
  expect_inspect %(/\\//), %(RegexLiteral[StringLiteral["/"]])
  expect_inspect %(/\#{1 / 2}/), <<-CRYSTAL
    RegexLiteral[
      StringInterpolation[
        Call[NumberLiteral["1", :i32], "/", [NumberLiteral["2", :i32]]]
      ]
    ]
    CRYSTAL
  expect_inspect %<%r(/)>, %(RegexLiteral[StringLiteral["/"]])
  expect_inspect %(/ /), %(RegexLiteral[StringLiteral[" "]])
  expect_inspect %(%r( )), %(RegexLiteral[StringLiteral[" "]])
  expect_inspect %(foo &.bar), %(Call["foo", block: Block[Var["__arg0"], body: Call[Var["__arg0"], "bar"]]])
  expect_inspect %(foo &.bar(1, 2, 3)), <<-CRYSTAL
    Call[
      "foo",
      block: Block[
        Var["__arg0"],
        body: Call[
          Var["__arg0"],
          "bar",
          [NumberLiteral["1", :i32],
           NumberLiteral["2", :i32],
           NumberLiteral["3", :i32]]
        ]
      ]
    ]
    CRYSTAL
  expect_inspect %(foo { |i| i.bar { i } }), <<-CRYSTAL
    Call[
      "foo",
      block: Block[
        Var["i"],
        body: Call[Var["i"], "bar", block: Block[body: Var["i"]]]
      ]
    ]
    CRYSTAL
  expect_inspect %(foo do |k, v|\n  k.bar(1, 2, 3)\nend), <<-CRYSTAL
    Call[
      "foo",
      block: Block[
        Var["k"], Var["v"],
        body: Call[
          Var["k"],
          "bar",
          [NumberLiteral["1", :i32],
           NumberLiteral["2", :i32],
           NumberLiteral["3", :i32]]
        ]
      ]
    ]
    CRYSTAL
  expect_inspect %(foo(3, &.*(2))), <<-CRYSTAL
    Call[
      "foo",
      [NumberLiteral["3", :i32]],
      block: Block[
        Var["__arg0"],
        body: Call[Var["__arg0"], "*", [NumberLiteral["2", :i32]]]
      ]
    ]
    CRYSTAL
  expect_inspect %(return begin\n  1\n  2\nend), %(Return[Expressions.begin(NumberLiteral["1", :i32], NumberLiteral["2", :i32])])
  expect_inspect %(macro foo\n  %bar = 1\nend), <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[MacroLiteral["  "], MacroVar["bar"], MacroLiteral[" = 1\\n"]]
    ]
    CRYSTAL
  expect_inspect %(macro foo\n  %bar = 1; end), <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[MacroLiteral["  "], MacroVar["bar"], MacroLiteral[" = 1; "]]
    ]
    CRYSTAL
  expect_inspect %(macro foo\n  %bar{1, x} = 1\nend), <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[
        MacroLiteral["  "],
        MacroVar["bar", exps: [NumberLiteral["1", :i32], Var["x"]]],
        MacroLiteral[" = 1\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %({% foo %}), %(MacroExpression[Var["foo"], output: false])
  expect_inspect %({{ foo }}), %(MacroExpression[Var["foo"]])
  expect_inspect %({% if foo %}\n  foo_then\n{% end %}), %(MacroIf[Var["foo"], MacroLiteral["\\n" + "  foo_then\\n"]])
  expect_inspect %({% if foo %}\n  foo_then\n{% else %}\n  foo_else\n{% end %}), <<-CRYSTAL
    MacroIf[
      Var["foo"],
      MacroLiteral["\\n" + "  foo_then\\n"],
      MacroLiteral["\\n" + "  foo_else\\n"]
    ]
    CRYSTAL
  expect_inspect %({% for foo in bar %}\n  {{ foo }}\n{% end %}), <<-CRYSTAL
    MacroFor[
      [Var["foo"]],
      Var["bar"],
      Expressions[
        MacroLiteral["\\n" + "  "],
        MacroExpression[Var["foo"]],
        MacroLiteral["\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %(macro foo\n  {% for foo in bar %}\n    {{ foo }}\n  {% end %}\nend), <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[
        MacroLiteral["  "],
        MacroFor[
          [Var["foo"]],
          Var["bar"],
          Expressions[
            MacroLiteral["\\n" + "    "],
            MacroExpression[Var["foo"]],
            MacroLiteral["\\n" + "  "]
          ]
        ],
        MacroLiteral["\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %[1.as(Int32)], %(Cast[NumberLiteral["1", :i32], Path["Int32"]])
  expect_inspect %[(1 || 1.1).as(Int32)], <<-CRYSTAL
    Cast[
      Expressions.paren(Or[NumberLiteral["1", :i32], NumberLiteral["1.1", :f64]]),
      Path["Int32"]
    ]
    CRYSTAL
  expect_inspect %[1 & 2 & (3 | 4)], <<-CRYSTAL
    Call[
      Call[NumberLiteral["1", :i32], "&", [NumberLiteral["2", :i32]]],
      "&",
      [Expressions.paren(
         Call[NumberLiteral["3", :i32], "|", [NumberLiteral["4", :i32]]]
       )]
    ]
    CRYSTAL
  expect_inspect %[(1 & 2) & (3 | 4)], <<-CRYSTAL
    Call[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "&", [NumberLiteral["2", :i32]]]
      ),
      "&",
      [Expressions.paren(
         Call[NumberLiteral["3", :i32], "|", [NumberLiteral["4", :i32]]]
       )]
    ]
    CRYSTAL
  expect_inspect %Q{def foo(x : T = 1)\nend}, <<-CRYSTAL
    Def[
      "foo",
      [Arg["x", default_value: NumberLiteral["1", :i32], restriction: Path["T"]]],
      Nop.new
    ]
    CRYSTAL
  expect_inspect %Q{def foo(x : X, y : Y) forall X, Y\nend}, <<-CRYSTAL
    Def[
      "foo",
      [Arg["x", restriction: Path["X"]], Arg["y", restriction: Path["Y"]]],
      Nop.new
    ]
    CRYSTAL
  expect_inspect %(foo : A | (B -> C)), <<-CRYSTAL
      TypeDeclaration[
        Var["foo"],
        Union[Path["A"], Union.parens(ProcNotation[Path["B"], Path["C"]])]
      ]
      CRYSTAL
  expect_inspect %(x : (A | B)), <<-CRYSTAL
      TypeDeclaration[Var["x"], Union.parens(Path["A"], Path["B"])]
      CRYSTAL
  expect_inspect %(foo : Int32 = 1), <<-CRYSTAL
      TypeDeclaration[Var["foo"], Path["Int32"], value: NumberLiteral["1", :i32]]
      CRYSTAL
  expect_inspect %(foo = uninitialized Int32), <<-CRYSTAL
      UninitializedVar[Var["foo"], Path["Int32"]]
      CRYSTAL
  expect_inspect %[%("\#{foo}")], <<-CRYSTAL
    StringInterpolation[StringLiteral["\\""], Call["foo"], StringLiteral["\\""]]
    CRYSTAL
  expect_inspect %Q{class Foo\n  private def bar\n  end\nend}, <<-CRYSTAL
      ClassDef[
        Path["Foo"],
        body: VisibilityModifier[
          Crystal::Visibility::Private,
          Def["bar", [], Nop.new]
        ]
      ]
      CRYSTAL
  expect_inspect %q{abstract class Foo(T) < Bar; end}, <<-CRYSTAL
      ClassDef[
        Path["Foo"],
        superclass: Path["Bar"],
        type_vars: ["T"],
        abstract: true,
        body: Nop.new
      ]
      CRYSTAL
  expect_inspect %q{struct Foo; end}, %q{ClassDef[Path["Foo"], struct: true, body: Nop.new]}
  expect_inspect %q{module Foo(T); end}, %q{ModuleDef[Path["Foo"], type_vars: ["T"], body: Nop.new]}
  expect_inspect %q{annotation Foo; end}, %q(AnnotationDef[Path["Foo"]])
  expect_inspect %q{foo(&.==(2))}, <<-CRYSTAL
      Call[
        "foo",
        block: Block[
          Var["__arg0"],
          body: Call[Var["__arg0"], "==", [NumberLiteral["2", :i32]]]
        ]
      ]
      CRYSTAL
  expect_inspect %q{foo.nil?}, %(IsA[Call["foo"], Path.global("Nil"), nil_check: true])
  expect_inspect %q{foo._bar}, %(Call[Call["foo"], "_bar"])
  expect_inspect %q{foo._bar(1)}, %(Call[Call["foo"], "_bar", [NumberLiteral["1", :i32]]])
  expect_inspect %q{_foo.bar}, %(Call[Call["_foo"], "bar"])
  expect_inspect %q{1.responds_to?(:inspect)}, %(RespondsTo[NumberLiteral["1", :i32], "inspect"])
  expect_inspect %q{1.responds_to?(:"&&")}, %(RespondsTo[NumberLiteral["1", :i32], "&&"])
  expect_inspect %Q{macro foo(x, *y)\nend}, %(Macro["foo", [Arg["x"], Arg["y"]], Expressions[], splat_index: 1])

  expect_inspect %q{{ {1, 2, 3} }}, <<-CRYSTAL
    TupleLiteral[
      TupleLiteral[
        NumberLiteral["1", :i32],
        NumberLiteral["2", :i32],
        NumberLiteral["3", :i32]
      ]
    ]
    CRYSTAL
  expect_inspect %q{{ {1 => 2} }}, <<-CRYSTAL
    TupleLiteral[
      HashLiteral[
        HashLiteral::Entry[NumberLiteral["1", :i32], NumberLiteral["2", :i32]]
      ]
    ]
    CRYSTAL
  expect_inspect %q{{ {1, 2, 3} => 4 }}, <<-CRYSTAL
    HashLiteral[
      HashLiteral::Entry[
        TupleLiteral[
          NumberLiteral["1", :i32],
          NumberLiteral["2", :i32],
          NumberLiteral["3", :i32]
        ],
        NumberLiteral["4", :i32]
      ]
    ]
    CRYSTAL
  expect_inspect %q{{ {foo: 2} }}, %(TupleLiteral[NamedTupleLiteral["foo": NumberLiteral["2", :i32]]])
  expect_inspect %Q{def foo(*args)\nend}, %(Def["foo", [Arg["args"]], Nop.new, splat_index: 0])
  expect_inspect %Q{def foo(*args : _)\nend}, %(Def["foo", [Arg["args", restriction: Underscore.new]], Nop.new, splat_index: 0])
  expect_inspect %Q{def foo(**args)\nend}, %(Def["foo", [], Nop.new, double_splat: Arg["args"]])
  expect_inspect %Q{def foo(**args : T)\nend}, %(Def["foo", [], Nop.new, double_splat: Arg["args", restriction: Path["T"]]])
  expect_inspect %Q{def foo(x, **args)\nend}, %(Def["foo", [Arg["x"]], Nop.new, double_splat: Arg["args"]])
  expect_inspect %Q{def foo(x, **args, &block)\nend}, <<-CRYSTAL
    Def[
      "foo",
      [Arg["x"]],
      Nop.new,
      block_arg: Arg["block"],
      block_arity: 0,
      double_splat: Arg["args"]
    ]
    CRYSTAL
  expect_inspect %Q{def foo(x, **args, &block : (_ -> _))\nend}, <<-CRYSTAL
    Def[
      "foo",
      [Arg["x"]],
      Nop.new,
      block_arg: Arg[
        "block",
        restriction: Union.parens(ProcNotation[Underscore.new, Underscore.new])
      ],
      block_arity: 1,
      double_splat: Arg["args"]
    ]
    CRYSTAL
  expect_inspect %Q{def foo(& : (->))\nend}, <<-CRYSTAL
    Def[
      "foo",
      [],
      Nop.new,
      block_arg: Arg["", restriction: Union.parens(ProcNotation[])],
      block_arity: 0
    ]
    CRYSTAL
  expect_inspect %Q{macro foo(**args)\nend}, %(Macro["foo", [], Expressions[], double_splat: Arg["args"]])
  expect_inspect %Q{macro foo(x, **args)\nend}, %(Macro["foo", [Arg["x"]], Expressions[], double_splat: Arg["args"]])
  expect_inspect %Q{def foo(x y)\nend}, %(Def["foo", [Arg["y", external_name: "x"]], Nop.new])
  expect_inspect %(foo("bar baz": 2)), %(Call["foo", named_args: [NamedArgument["bar baz", NumberLiteral["2", :i32]]]])
  expect_inspect %(Foo("bar baz": Int32)), %(Generic[Path["Foo"], [], named_args: [NamedArgument["bar baz", Path["Int32"]]]])
  expect_inspect %({"foo bar": 1}), %(NamedTupleLiteral["foo bar": NumberLiteral["1", :i32]])
  expect_inspect %(def foo("bar baz" qux)\nend), %(Def["foo", [Arg["qux", external_name: "bar baz"]], Nop.new])
  expect_inspect %q{foo()}, %(Call["foo"])
  expect_inspect %q{/a/x}, %(RegexLiteral[StringLiteral["a"], options: Regex::Options::EXTENDED])
  expect_inspect %q{1_f32}, %(NumberLiteral["1", :f32])
  expect_inspect %q{1_f64}, %(NumberLiteral["1", :f64])
  expect_inspect %q{1.0}, %(NumberLiteral["1.0", :f64])
  expect_inspect %q{1e10_f64}, %(NumberLiteral["1e10", :f64])
  expect_inspect %q{!a}, %(Not[Call["a"]])
  expect_inspect %q{!(1 < 2)}, <<-CRYSTAL
    Not[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "<", [NumberLiteral["2", :i32]]]
      )
    ]
    CRYSTAL
  expect_inspect %q{(1 + 2)..3}, <<-CRYSTAL
    RangeLiteral[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
      ),
      NumberLiteral["3", :i32]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n{{ @type }}\nend}, <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[MacroExpression[InstanceVar["@type"]], MacroLiteral["\\n"]]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n\\{{ @type }}\nend}, %(Macro["foo", [], Expressions[MacroLiteral["{"], MacroLiteral["{ @type }}\\n"]]])
  expect_inspect %Q{macro foo\n{% @type %}\nend}, <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[
        MacroExpression[InstanceVar["@type"], output: false],
        MacroLiteral["\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n{{ @type }}\nend}, <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[MacroExpression[InstanceVar["@type"]], MacroLiteral["\\n"]]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n\\{{ @type }}\nend}, %(Macro["foo", [], Expressions[MacroLiteral["{"], MacroLiteral["{ @type }}\\n"]]])
  expect_inspect %Q{macro foo\n{% @type %}\nend}, <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[
        MacroExpression[InstanceVar["@type"], output: false],
        MacroLiteral["\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n\\{%@type %}\nend}, %(Macro["foo", [], Expressions[MacroLiteral["{%"], MacroLiteral["@type %}\\n"]]])
  expect_inspect %Q{enum A : B\nend}, %(EnumDef[Path["A"], base_type: Path["B"]])
  expect_inspect %Q{# doc\ndef foo\nend}, %(Def["foo", [], Nop.new])
  expect_inspect %q{foo[x, y, a: 1, b: 2]}, <<-CRYSTAL
    Call[
      Call["foo"],
      "[]",
      [Call["x"], Call["y"]],
      named_args: [NamedArgument["a", NumberLiteral["1", :i32]],
       NamedArgument["b", NumberLiteral["2", :i32]]]
    ]
    CRYSTAL
  expect_inspect %q{foo[x, y, a: 1, b: 2] = z}, <<-CRYSTAL
    Call[
      Call["foo"],
      "[]=",
      [Call["x"], Call["y"], Call["z"]],
      named_args: [NamedArgument["a", NumberLiteral["1", :i32]],
       NamedArgument["b", NumberLiteral["2", :i32]]]
    ]
    CRYSTAL
  expect_inspect %(@[Foo(1, 2, a: 1, b: 2)]), <<-CRYSTAL
    Annotation[
      Path["Foo"],
      named_args: [NamedArgument["a", NumberLiteral["1", :i32]],
       NamedArgument["b", NumberLiteral["2", :i32]]]
    ]
    CRYSTAL
  expect_inspect %(lib Foo\nend), %(LibDef[Path["Foo"], Nop.new])
  expect_inspect %(fun foo(a : Void, b : Void, ...) : Void\n\nend), <<-CRYSTAL
    FunDef[
      "foo",
      Arg["a", restriction: Path["Void"]], Arg["b", restriction: Path["Void"]],
      return_type: Path["Void"],
      varargs: true,
      real_name: "foo",
      body: Nop.new
    ]
    CRYSTAL
  expect_inspect %(lib Foo\n  struct Foo\n    a : Void\n    b : Void\n  end\nend), <<-CRYSTAL
    LibDef[
      Path["Foo"],
      CStructOrUnionDef[
        "Foo",
        Expressions[
          TypeDeclaration[Var["a"], Path["Void"]],
          TypeDeclaration[Var["b"], Path["Void"]]
        ]
      ]
    ]
    CRYSTAL
  expect_inspect %(lib Foo\n  union Foo\n    a : Int\n    b : Int32\n  end\nend), <<-CRYSTAL
    LibDef[
      Path["Foo"],
      CStructOrUnionDef[
        "Foo",
        Expressions[
          TypeDeclaration[Var["a"], Path["Int"]],
          TypeDeclaration[Var["b"], Path["Int32"]]
        ],
        union: true
      ]
    ]
    CRYSTAL
  expect_inspect %(lib Foo\n  FOO = 0\nend), %(LibDef[Path["Foo"], Assign[Path["FOO"], NumberLiteral["0", :i32]]])
  expect_inspect %(lib LibC\n  fun getch = "get.char"\nend), %(LibDef[Path["LibC"], FunDef["getch", real_name: "get.char"]])
  expect_inspect %(enum Foo\n  A = 0\n  B\nend), <<-CRYSTAL
    EnumDef[
      Path["Foo"],
      Arg["A", default_value: NumberLiteral["0", :i32]], Arg["B"]
    ]
    CRYSTAL
  expect_inspect %(alias Foo = Void), %(Alias[Path["Foo"], Path["Void"]])
  expect_inspect %(alias Foo::Bar = Void), %(Alias[Path["Foo", "Bar"], Path["Void"]])
  expect_inspect %(type(Foo = Void)), %(Call["type", [Assign[Path["Foo"], Path["Void"]]]])
  expect_inspect %(return true ? 1 : 2), <<-CRYSTAL
    Return[
      If[
        BoolLiteral[true],
        NumberLiteral["1", :i32],
        NumberLiteral["2", :i32],
        ternary: true
      ]
    ]
    CRYSTAL
  expect_inspect %(1 <= 2 <= 3), <<-CRYSTAL
    Call[
      Call[NumberLiteral["1", :i32], "<=", [NumberLiteral["2", :i32]]],
      "<=",
      [NumberLiteral["3", :i32]]
    ]
    CRYSTAL
  expect_inspect %((1 <= 2) <= 3), <<-CRYSTAL
    Call[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "<=", [NumberLiteral["2", :i32]]]
      ),
      "<=",
      [NumberLiteral["3", :i32]]
    ]
    CRYSTAL
  expect_inspect %(1 <= (2 <= 3)), <<-CRYSTAL
    Call[
      NumberLiteral["1", :i32],
      "<=",
      [Expressions.paren(
         Call[NumberLiteral["2", :i32], "<=", [NumberLiteral["3", :i32]]]
       )]
    ]
    CRYSTAL
  expect_inspect %(case 1; when .foo?; 2; end), <<-CRYSTAL
    Case[
      When[Call[ImplicitObj.new, "foo?"], NumberLiteral["2", :i32]],
      cond: NumberLiteral["1", :i32]
    ]
    CRYSTAL
  expect_inspect %(select; when foo.bar; 2; end), <<-CRYSTAL
    Select[When[Call[Call["foo"], "bar"], NumberLiteral["2", :i32]]]
    CRYSTAL
  expect_inspect %(select; when foo.bar; 2; else 3; end), <<-CRYSTAL
    Select[
      When[Call[Call["foo"], "bar"], NumberLiteral["2", :i32]],
      else: NumberLiteral["3", :i32]
    ]
    CRYSTAL
  expect_inspect %(case 1; in .foo?; 2; end), <<-CRYSTAL
    Case[
      When[
        Call[ImplicitObj.new, "foo?"],
        NumberLiteral["2", :i32],
        exhaustive: true
      ],
      cond: NumberLiteral["1", :i32],
      exhaustive: true
    ]
    CRYSTAL
  expect_inspect %(case 1; when .!; 2; when .< 0; 3; end), <<-CRYSTAL
    Case[
      When[Not[ImplicitObj.new], NumberLiteral["2", :i32]],
      When[
        Call[ImplicitObj.new, "<", [NumberLiteral["0", :i32]]],
        NumberLiteral["3", :i32]
      ],
      cond: NumberLiteral["1", :i32]
    ]
    CRYSTAL
  expect_inspect %(case 1\nwhen .[](2)\n  3\nwhen .[]=(4)\n  5\nend), <<-CRYSTAL
    Case[
      When[
        Call[ImplicitObj.new, "[]", [NumberLiteral["2", :i32]]],
        NumberLiteral["3", :i32]
      ],
      When[
        Call[ImplicitObj.new, "[]=", [NumberLiteral["4", :i32]]],
        NumberLiteral["5", :i32]
      ],
      cond: NumberLiteral["1", :i32]
    ]
    CRYSTAL
  expect_inspect %({(1 + 2)}), <<-CRYSTAL
    TupleLiteral[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
      )
    ]
    CRYSTAL
  expect_inspect %({foo: (1 + 2)}), <<-CRYSTAL
    NamedTupleLiteral[
      "foo": Expressions.paren(
        Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
      )
    ]
    CRYSTAL
  expect_inspect %q("#{(1 + 2)}"), <<-CRYSTAL
    StringInterpolation[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
      )
    ]
    CRYSTAL
  expect_inspect %({(1 + 2) => (3 + 4)}), <<-CRYSTAL
    HashLiteral[
      HashLiteral::Entry[
        Expressions.paren(
          Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
        ),
        Expressions.paren(
          Call[NumberLiteral["3", :i32], "+", [NumberLiteral["4", :i32]]]
        )
      ]
    ]
    CRYSTAL
  expect_inspect %([(1 + 2)] of Int32), <<-CRYSTAL
    ArrayLiteral[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]]
      ),
      of: Path["Int32"]
    ]
    CRYSTAL
  expect_inspect %(foo(1, (2 + 3), bar: (4 + 5))), <<-CRYSTAL
    Call[
      "foo",
      [NumberLiteral["1", :i32],
       Expressions.paren(
         Call[NumberLiteral["2", :i32], "+", [NumberLiteral["3", :i32]]]
       )],
      named_args: [NamedArgument[
         "bar",
         Expressions.paren(
           Call[NumberLiteral["4", :i32], "+", [NumberLiteral["5", :i32]]]
         )
       ]]
    ]
    CRYSTAL
  expect_inspect %(if (1 + 2\n3)\n  4\nend), <<-CRYSTAL
    If[
      Expressions.paren(
        Call[NumberLiteral["1", :i32], "+", [NumberLiteral["2", :i32]]],
        NumberLiteral["3", :i32]
      ),
      NumberLiteral["4", :i32],
      Nop.new
    ]
    CRYSTAL
  expect_inspect %q(while foo; bar; end), %(While[Call["foo"], body: Call["bar"]])
  expect_inspect %q(until foo; bar; end), %(Until[Call["foo"], body: Call["bar"]])
  expect_inspect %q{%x(whoami)}, %(Call["`", [StringLiteral["whoami"]]])
  expect_inspect %(begin\n  ()\nend), %(Expressions.begin(Expressions.paren(Nop.new)))
  expect_inspect %q("\e\0\""), %q(StringLiteral["\e\u0000\""])
  expect_inspect %q("#{1}\0"), <<-CRYSTAL
    StringInterpolation[NumberLiteral["1", :i32], StringLiteral["\\u0000"]]
    CRYSTAL
  expect_inspect %q(%r{\/\0}), %(RegexLiteral[StringLiteral["/\\\\0"]])
  expect_inspect %q(%r{#{1}\/\0}), <<-CRYSTAL
    RegexLiteral[
      StringInterpolation[
        NumberLiteral["1", :i32], StringLiteral["/"], StringLiteral["\\\\0"]
      ]
    ]
    CRYSTAL
  expect_inspect %q(`\n\0`), %(Call["`", [StringLiteral["\\n" + "\\u0000"]]])
  expect_inspect %q(`#{1}\n\0`), <<-CRYSTAL
    Call[
      "`",
      [StringInterpolation[
         NumberLiteral["1", :i32], StringLiteral["\\n"], StringLiteral["\\u0000"]
       ]]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n{% verbatim do %}1{% end %}\nend}, <<-CRYSTAL
    Macro[
      "foo",
      [],
      Expressions[MacroVerbatim[MacroLiteral["1"]], MacroLiteral["\\n"]]
    ]
    CRYSTAL
  expect_inspect %q{foo.*}, %(Call[Call["foo"], "*"])
  expect_inspect %q{foo.%}, %(Call[Call["foo"], "%"])
  expect_inspect %q{&+1}, %(Call[NumberLiteral["1", :i32], "&+"])
  expect_inspect %q{&-1}, %(Call[NumberLiteral["1", :i32], "&-"])
  expect_inspect %q{1.&*}, %(Call[NumberLiteral["1", :i32], "&*"])
  expect_inspect %q{1.&**}, %(Call[NumberLiteral["1", :i32], "&**"])
  expect_inspect %q{1.~(2)}, %(Call[NumberLiteral["1", :i32], "~", [NumberLiteral["2", :i32]]])
  expect_inspect %Q{1.~(2) do\nend}, <<-CRYSTAL
    Call[
      NumberLiteral["1", :i32],
      "~",
      [NumberLiteral["2", :i32]],
      block: Block[body: Nop.new]
    ]
    CRYSTAL
  expect_inspect %Q{1.+ do\nend}, %(Call[NumberLiteral["1", :i32], "+", block: Block[body: Nop.new]])
  expect_inspect %Q{1.[](2) do\nend}, <<-CRYSTAL
    Call[
      NumberLiteral["1", :i32],
      "[]",
      [NumberLiteral["2", :i32]],
      block: Block[body: Nop.new]
    ]
    CRYSTAL
  expect_inspect %q{1.[]=}, %(Call[NumberLiteral["1", :i32], "[]="])
  expect_inspect %q{1.+(a: 2)}, <<-CRYSTAL
    Call[
      NumberLiteral["1", :i32],
      "+",
      named_args: [NamedArgument["a", NumberLiteral["2", :i32]]]
    ]
    CRYSTAL
  expect_inspect %q{1.+(&block)}, %(Call[NumberLiteral["1", :i32], "+", block_arg: Call["block"]])
  expect_inspect %q{1.//(2, a: 3)}, <<-CRYSTAL
    Call[
      NumberLiteral["1", :i32],
      "//",
      [NumberLiteral["2", :i32]],
      named_args: [NamedArgument["a", NumberLiteral["3", :i32]]]
    ]
    CRYSTAL
  expect_inspect %q{1.//(2, &block)}, <<-CRYSTAL
    Call[
      NumberLiteral["1", :i32],
      "//",
      [NumberLiteral["2", :i32]],
      block_arg: Call["block"]
    ]
    CRYSTAL
  expect_inspect %({% verbatim do %}\n  1{{ 2 }}\n  3{{ 4 }}\n{% end %}), <<-CRYSTAL
    MacroVerbatim[
      Expressions[
        MacroLiteral["\\n" + "  1"],
        MacroExpression[NumberLiteral["2", :i32]],
        MacroLiteral["\\n" + "  3"],
        MacroExpression[NumberLiteral["4", :i32]],
        MacroLiteral["\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %({% for foo in bar %}\n  {{ if true\n  foo\n  bar\nend }}\n{% end %}), <<-CRYSTAL
    MacroFor[
      [Var["foo"]],
      Var["bar"],
      Expressions[
        MacroLiteral["\\n" + "  "],
        MacroExpression[
          If[BoolLiteral[true], Expressions[Var["foo"], Var["bar"]], Nop.new]
        ],
        MacroLiteral["\\n"]
      ]
    ]
    CRYSTAL
  expect_inspect %(asm("nop" ::::)), %(Asm["nop"])
  expect_inspect %(asm("nop" : "a"(1), "b"(2) : "c"(3), "d"(4) : "e", "f" : "volatile", "alignstack", "intel")), <<-CRYSTAL
    Asm[
      "nop",
      outputs: [AsmOperand["a", NumberLiteral["1", :i32]],
       AsmOperand["b", NumberLiteral["2", :i32]]],
      inputs: [AsmOperand["c", NumberLiteral["3", :i32]],
       AsmOperand["d", NumberLiteral["4", :i32]]],
      clobbers: ["e", "f"],
      volatile: true,
      alignstack: true,
      intel: true
    ]
    CRYSTAL
  expect_inspect %(asm("nop" :: "c"(3), "d"(4) ::)), <<-CRYSTAL
    Asm[
      "nop",
      inputs: [AsmOperand["c", NumberLiteral["3", :i32]],
       AsmOperand["d", NumberLiteral["4", :i32]]]
    ]
    CRYSTAL
  expect_inspect %(asm("nop" :::: "volatile")), %(Asm["nop", volatile: true])
  expect_inspect %(asm("nop" :: "a"(1) :: "volatile")), %(Asm["nop", inputs: [AsmOperand["a", NumberLiteral["1", :i32]]], volatile: true])
  expect_inspect %(asm("nop" ::: "e" : "volatile")), %(Asm["nop", clobbers: ["e"], volatile: true])
  expect_inspect %[(1..)], %(Expressions.paren(RangeLiteral[NumberLiteral["1", :i32], Nop.new]))
  expect_inspect %[..3], %(RangeLiteral[Nop.new, NumberLiteral["3", :i32]])
  expect_inspect %q{offsetof(Foo, @bar)}, %(OffsetOf[Path["Foo"], InstanceVar["@bar"]])
  expect_inspect %Q{def foo(**options, &block)\nend}, <<-CRYSTAL
    Def[
      "foo",
      [],
      Nop.new,
      block_arg: Arg["block"],
      block_arity: 0,
      double_splat: Arg["options"]
    ]
    CRYSTAL
  expect_inspect %Q{macro foo\n  123\nend}, %(Macro["foo", [], MacroLiteral["  123\\n"]])
  expect_inspect %Q{if true\n(  1)\nend}, %(If[BoolLiteral[true], Expressions.paren(NumberLiteral["1", :i32]), Nop.new])
  expect_inspect %Q{unless true\n(  1)\nend}, %(Unless[BoolLiteral[true], Expressions.paren(NumberLiteral["1", :i32]), Nop.new])
  expect_inspect %Q{begin\n(  1)\nrescue\nend}, <<-CRYSTAL
    ExceptionHandler[
      rescues: [Rescue[]],
      body: Expressions.paren(NumberLiteral["1", :i32])
    ]
    CRYSTAL
  expect_inspect %q{begin; rescue exc; end}, <<-CRYSTAL
    ExceptionHandler[rescues: [Rescue[name: "exc"]]]
    CRYSTAL
  expect_inspect %q{begin; rescue exc : Foo; end}, <<-CRYSTAL
    ExceptionHandler[rescues: [Rescue[types: [Path["Foo"]], name: "exc"]]]
    CRYSTAL
  expect_inspect %q{begin; rescue Foo | Bar; end}, <<-CRYSTAL
    ExceptionHandler[rescues: [Rescue[types: [Path["Foo"], Path["Bar"]]]]]
    CRYSTAL
  expect_inspect %q{begin; 2; ensure; 1; end}, <<-CRYSTAL
    ExceptionHandler[
      ensure: NumberLiteral["1", :i32],
      body: NumberLiteral["2", :i32]
    ]
    CRYSTAL
  expect_inspect %[他.说("你好")], %(Call[Call["他"], "说", [StringLiteral["你好"]]])
  expect_inspect %[他.说 = "你好"], %(Call[Call["他"], "说=", [StringLiteral["你好"]]])
  expect_inspect %[あ.い, う.え.お = 1, 2], <<-CRYSTAL
    MultiAssign[
      [Call[Call["あ"], "い"], Call[Call[Call["う"], "え"], "お"]],
      [NumberLiteral["1", :i32], NumberLiteral["2", :i32]]
    ]
    CRYSTAL
  expect_inspect %q(Foo(Bar)), %(Generic[Path["Foo"], [Path["Bar"]]])
  expect_inspect %q(Foo?), <<-CRYSTAL
    Generic.question(Path.global("Union"), [Path["Foo"], Path.global("Nil")])
    CRYSTAL
  expect_inspect %q(Foo(Bar*)), %q(Generic[Path["Foo"], [Generic.asterisk(Path.global("Pointer"), [Path["Bar"]])]])
  expect_inspect %q(Foo(Bar[12])), <<-CRYSTAL
    Generic[
      Path["Foo"],
      [Generic.bracket(
         Path.global("StaticArray"),
         [Path["Bar"], NumberLiteral["12", :i32]]
       )]
    ]
    CRYSTAL
  expect_inspect %q(nil), %(NilLiteral.new)
  expect_inspect %q('c'), %(CharLiteral['c'])
  expect_inspect %q(Set(String){"foo", "bar"}), <<-CRYSTAL
    ArrayLiteral[
      StringLiteral["foo"], StringLiteral["bar"],
      name: Generic[Path["Set"], [Path["String"]]]
    ]
    CRYSTAL
  expect_inspect %q(1...2), <<-CRYSTAL
    RangeLiteral[
      NumberLiteral["1", :i32],
      NumberLiteral["2", :i32],
      exclusive: true
    ]
    CRYSTAL
  expect_inspect %q(/foo/ix), <<-CRYSTAL
    RegexLiteral[
      StringLiteral["foo"],
      options: Regex::Options[IGNORE_CASE, EXTENDED]
    ]
    CRYSTAL
  expect_inspect %q(foo = 1; foo += 2), <<-CRYSTAL
    Expressions[
      Assign[Var["foo"], NumberLiteral["1", :i32]],
      OpAssign[Var["foo"], "+", NumberLiteral["2", :i32]]
    ]
    CRYSTAL
  expect_inspect %q(foo.@bar), %(ReadInstanceVar[Call["foo"], "@bar"])
  expect_inspect %q(@@bar), %(ClassVar["@@bar"])
  expect_inspect %q($?), %(Global["$?"])
  expect_inspect %q(def Foo.bar; end), <<-CRYSTAL
    Def["bar", [], Nop.new, receiver: Path["Foo"]]
    CRYSTAL
  expect_inspect %q(abstract def foo : _), %q(Def["foo", [], Nop.new, return_type: Underscore.new, abstract: true])
  expect_inspect %q(pointerof(foo)), %(PointerOf[Call["foo"]])
  expect_inspect %q(sizeof(Int32)), %(SizeOf[Path["Int32"]])
  expect_inspect %q(instance_sizeof(Int32)), %(InstanceSizeOf[Path["Int32"]])
  expect_inspect %q(alignof(Int32)), %(AlignOf[Path["Int32"]])
  expect_inspect %q(instance_alignof(Int32)), %(InstanceAlignOf[Path["Int32"]])
  expect_inspect %q(LibFoo.bar(out baz)), <<-CRYSTAL
    Call[Path["LibFoo"], "bar", [Out[Var["baz"]]]]
    CRYSTAL
  expect_inspect %q(private def foo; end), %(VisibilityModifier[Crystal::Visibility::Private, Def["foo", [], Nop.new]])
  expect_inspect %q(require "foo"), %(Require["foo"])
  expect_inspect %q(->(i : Int32) { i * 2 }), <<-CRYSTAL
    ProcLiteral[
      Def[
        "->",
        [Arg["i", restriction: Path["Int32"]]],
        Call[Var["i"], "*", [NumberLiteral["2", :i32]]]
      ]
    ]
    CRYSTAL
  expect_inspect %q(->add(Int32, Int32)), <<-CRYSTAL
    ProcPointer["add", [Path["Int32"], Path["Int32"]]]
    CRYSTAL
  expect_inspect %q(->Foo.add), <<-CRYSTAL
    ProcPointer[Path["Foo"], "add"]
    CRYSTAL
  expect_inspect %q(yield), %(Yield[])
  expect_inspect %q(with foo yield), %(Yield[scope: Call["foo"]])
  expect_inspect %q(yield 1), %(Yield[NumberLiteral["1", :i32]])
  expect_inspect %q(yield(1, 2)), <<-CRYSTAL
    Yield[
      NumberLiteral["1", :i32], NumberLiteral["2", :i32],
      has_parentheses: true
    ]
    CRYSTAL
  expect_inspect %q(include Foo), %(Include[Path["Foo"]])
  expect_inspect %q(extend Foo), %(Extend[Path["Foo"]])
  expect_inspect %q(lib Foo; type Bar = Baz; end), <<-CRYSTAL
    LibDef[Path["Foo"], TypeDef["Bar", Path["Baz"]]]
    CRYSTAL
  expect_inspect %q(typeof(1)), %q(TypeOf[NumberLiteral["1", :i32]])
  expect_inspect %q(foo(*x)), %q(Call["foo", [Splat[Call["x"]]]])
  expect_inspect %q(foo(**x)), %q(Call["foo", [DoubleSplat[Call["x"]]]])
end
