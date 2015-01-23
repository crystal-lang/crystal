require "../../spec_helper"

private def expect_to_s(original, expected = original, file = __FILE__, line = __LINE__)
  it "does to_s of #{original.inspect}" do
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
end
