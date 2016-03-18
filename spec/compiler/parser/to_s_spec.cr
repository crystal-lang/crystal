require "../../spec_helper"

private def expect_to_s(original, expected = original, file = __FILE__, line = __LINE__)
  it "does to_s of #{original.inspect}", file, line do
    Parser.parse(original).to_s.should eq(expected), file, line
  end
end

describe "ASTNode#to_s" do
  expect_to_s "([] of T).foo"
  expect_to_s "({} of K => V).foo"
  expect_to_s "foo(bar)"
  expect_to_s "(~1).foo"
  expect_to_s "1 && (a = 2)"
  expect_to_s "(a = 2) && 1"
  expect_to_s "foo(a as Int32)", "foo((a as Int32))"
  expect_to_s "@foo.bar"
  expect_to_s %(:foo)
  expect_to_s %(:"{")
  expect_to_s %(/hello world/)
  expect_to_s %(/\\s/)
  expect_to_s %(/\\?/)
  expect_to_s %(/\\(group\\)/)
  expect_to_s %(/\\//), "/\\//"
  expect_to_s %(/\#{1 / 2}/)
  expect_to_s %(foo &.bar), %(foo(&.bar))
  expect_to_s %(foo &.bar(1, 2, 3)), %(foo(&.bar(1, 2, 3)))
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
  expect_to_s %[1 as Int32]
  expect_to_s %[(1 || 1.1) as Int32]
  expect_to_s %[1 & 2 & (3 | 4)], %[(1 & 2) & (3 | 4)]
  expect_to_s %[(1 & 2) & (3 | 4)]
  expect_to_s "def foo(x : T = 1)\nend"
  expect_to_s %(foo : A | (B -> C))
end
