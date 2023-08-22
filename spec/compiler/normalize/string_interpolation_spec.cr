require "../../spec_helper"

describe "Normalize: string interpolation" do
  it "normalizes string interpolation" do
    assert_expand %("foo\#{bar}baz"), %(::String.interpolation("foo", bar, "baz"))
  end

  it "normalizes string interpolation with multiple lines" do
    assert_expand %("foo\n\#{bar}\nbaz\nqux\nfox"), %(::String.interpolation("foo\\n", bar, "\\nbaz\\nqux\\nfox"))
  end

  it "normalizes heredoc" do
    assert_normalize "<<-FOO\nhello\nFOO", %("hello")
  end

  it "replaces string constant" do
    result = semantic(%(
      def String.interpolation(*args); ""; end

      OBJ = "world"

      "hello \#{OBJ}"
    ))
    node = result.node.as(Expressions).last
    string = node.should be_a(StringLiteral)
    string.value.should eq("hello world")
  end

  it "replaces string constant that results from macro expansion" do
    result = semantic(%(
      def String.interpolation(*args); ""; end

      OBJ = {% if 1 + 1 == 2 %} "world" {% else %} "bug" {% end %}

      "hello \#{OBJ}"
    ))
    node = result.node.as(Expressions).last
    string = node.should be_a(StringLiteral)
    string.value.should eq("hello world")
  end

  it "replaces through multiple levels" do
    result = semantic(%(
      def String.interpolation(*args); ""; end

      OBJ1 = "ld"
      OBJ2 = "wor\#{OBJ1}"

      "hello \#{OBJ2}"
    ))
    node = result.node.as(Expressions).last
    string = node.should be_a(StringLiteral)
    string.value.should eq("hello world")
  end
end
