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

  it "replaces char constant" do
    result = semantic(%(
      def String.interpolation(*args); ""; end

      OBJ = 'l'

      "hello wor\#{OBJ}d"
    ))
    node = result.node.as(Expressions).last
    string = node.should be_a(StringLiteral)
    string.value.should eq("hello world")
  end

  it "replaces number constant" do
    result = semantic(%(
      def String.interpolation(*args); ""; end

      OBJ = 9_f32

      "nine as a float: \#{OBJ}"
    ))
    node = result.node.as(Expressions).last
    string = node.should be_a(StringLiteral)
    string.value.should eq("nine as a float: 9.0")
  end

  it "replaces boolean constant" do
    result = semantic(%(
      def String.interpolation(*args); ""; end

      OBJ = false

      "boolean false: \#{OBJ}"
    ))
    node = result.node.as(Expressions).last
    string = node.should be_a(StringLiteral)
    string.value.should eq("boolean false: false")
  end
end
