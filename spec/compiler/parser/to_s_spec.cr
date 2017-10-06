require "../../support/syntax"

private def expect_to_s(original, expected = original, emit_doc = false, file = __FILE__, line = __LINE__)
  it "does to_s of #{original.inspect}", file, line do
    str = IO::Memory.new expected.bytesize
    parser = Parser.new original
    parser.wants_doc = emit_doc
    parser.parse.to_s(str, emit_doc: emit_doc)
    str.to_s.should eq(expected), file, line
  end
end

describe "ASTNode#to_s" do
  expect_to_s "([] of T).foo"
  expect_to_s "({} of K => V).foo"
  expect_to_s "foo(bar)"
  expect_to_s "(~1).foo"
  expect_to_s "1 && (a = 2)"
  expect_to_s "(a = 2) && 1"
  expect_to_s "foo(a.as(Int32))"
  expect_to_s "(1 + 2).as(Int32)", "(1 + 2).as(Int32)"
  expect_to_s "a.as?(Int32)"
  expect_to_s "(1 + 2).as?(Int32)", "(1 + 2).as?(Int32)"
  expect_to_s "@foo.bar"
  expect_to_s %(:foo)
  expect_to_s %(:"{")
  expect_to_s %(/hello world/)
  expect_to_s %(/\\s/)
  expect_to_s %(/\\?/)
  expect_to_s %(/\\(group\\)/)
  expect_to_s %(/\\//), "/\\//"
  expect_to_s %(/\#{1 / 2}/)
  expect_to_s %<%r(/)>, %(/\\//)
  expect_to_s %(foo &.bar), %(foo(&.bar))
  expect_to_s %(foo &.bar(1, 2, 3)), %(foo(&.bar(1, 2, 3)))
  expect_to_s %(foo { |i| i.bar { i } }), "foo do |i|\n  i.bar do\n    i\n  end\nend"
  expect_to_s %(foo do |k, v|\n  k.bar(1, 2, 3)\nend)
  expect_to_s %(foo(3, &.*(2)))
  expect_to_s %(return begin\n  1\n  2\nend)
  expect_to_s %(macro foo\n  %bar = 1\nend)
  expect_to_s %(macro foo\n  %bar = 1; end)
  expect_to_s %(macro foo\n  %bar{1, x} = 1\nend)
  expect_to_s %({% foo %})
  expect_to_s %({{ foo }})
  expect_to_s %({% if foo %}\n  foo_then\n{% end %})
  expect_to_s %({% if foo %}\n  foo_then\n{% else %}\n  foo_else\n{% end %})
  expect_to_s %({% for foo in bar %}\n  {{ foo }}\n{% end %})
  expect_to_s %(macro foo\n  {% for foo in bar %}\n    {{ foo }}\n  {% end %}\nend)
  expect_to_s %[1.as(Int32)]
  expect_to_s %[(1 || 1.1).as(Int32)], %[(1 || 1.1).as(Int32)]
  expect_to_s %[1 & 2 & (3 | 4)], %[(1 & 2) & (3 | 4)]
  expect_to_s %[(1 & 2) & (3 | 4)]
  expect_to_s "def foo(x : T = 1)\nend"
  expect_to_s "def foo(x : X, y : Y) forall X, Y\nend"
  expect_to_s %(foo : A | (B -> C))
  expect_to_s %[%("\#{foo}")], %["\\\"\#{foo}\\\""]
  expect_to_s "class Foo\n  private def bar\n  end\nend"
  expect_to_s "foo(&.==(2))"
  expect_to_s "foo.nil?"
  expect_to_s "foo._bar"
  expect_to_s "foo._bar(1)"
  expect_to_s "_foo.bar"
  expect_to_s "1.responds_to?(:to_s)"
  expect_to_s "1.responds_to?(:\"&&\")"
  expect_to_s "macro foo(x, *y)\nend"
  expect_to_s "{ {1, 2, 3} }"
  expect_to_s "{ {1 => 2} }"
  expect_to_s "{ {1, 2, 3} => 4 }"
  expect_to_s "{ {foo: 2} }"
  expect_to_s "def foo(**args)\nend"
  expect_to_s "def foo(**args : T)\nend"
  expect_to_s "def foo(x, **args)\nend"
  expect_to_s "def foo(x, **args, &block)\nend"
  expect_to_s "macro foo(**args)\nend"
  expect_to_s "macro foo(x, **args)\nend"
  expect_to_s "def foo(x y)\nend"
  expect_to_s %(foo("bar baz": 2))
  expect_to_s %(Foo("bar baz": Int32))
  expect_to_s %({"foo bar": 1})
  expect_to_s %(def foo("bar baz" qux)\nend)
  expect_to_s "foo()"
  expect_to_s "/a/x"
  expect_to_s "1_f32", "1_f32"
  expect_to_s "1_f64", "1_f64"
  expect_to_s "1.0", "1.0"
  expect_to_s "1e10_f64", "1e10"
  expect_to_s "!a"
  expect_to_s "!(1 < 2)"
  expect_to_s "(1 + 2)..3"
  expect_to_s "macro foo\n{{ @type }}\nend"
  expect_to_s "macro foo\n\\{{ @type }}\nend"
  expect_to_s "macro foo\n{% @type %}\nend"
  expect_to_s "macro foo\n\\{%@type %}\nend"
  expect_to_s "enum A : B\nend"
  expect_to_s "# doc\ndef foo\nend", emit_doc: true
  expect_to_s "foo[x, y, a: 1, b: 2]"
  expect_to_s "foo[x, y, a: 1, b: 2] = z"
  expect_to_s %(@[Foo(1, 2, a: 1, b: 2)])
  expect_to_s %(lib Foo\nend)
  expect_to_s %(fun foo(a : Void, b : Void, ...) : Void\n\nend)
  expect_to_s %(lib Foo\n  struct Foo\n    a : Void\n    b : Void\n  end\nend)
  expect_to_s %(lib Foo\n  union Foo\n    a : Int\n    b : Int32\n  end\nend)
  expect_to_s %(lib Foo\n  FOO = 0\nend)
  expect_to_s %(enum Foo\n  A = 0\n  B\nend)
  expect_to_s %(alias Foo = Void)
  expect_to_s %(type(Foo = Void))
  expect_to_s %(return true ? 1 : 2), %(return begin\n  if true\n    1\n  else\n    2\n  end\nend)
  expect_to_s %(1 <= 2 <= 3)
  expect_to_s %((1 <= 2) <= 3)
  expect_to_s %(1 <= (2 <= 3))
end
