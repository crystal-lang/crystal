require "../../spec_helper"

describe "Normalize: case" do
  it "normalizes case with call" do
    assert_expand "case x; when 1; 'b'; when 2; 'c'; else; 'd'; end", "__temp_1 = x\nif 1 === __temp_1\n  'b'\nelse\n  if 2 === __temp_1\n    'c'\n  else\n    'd'\n  end\nend"
  end

  it "normalizes case with var in cond" do
    assert_expand_second "x = 1; case x; when 1; 'b'; end", "if 1 === x\n  'b'\nend"
  end

  it "normalizes case with Path to is_a?" do
    assert_expand_second "x = 1; case x; when Foo; 'b'; end", "if x.is_a?(Foo)\n  'b'\nend"
  end

  it "normalizes case with generic to is_a?" do
    assert_expand_second "x = 1; case x; when Foo(T); 'b'; end", "if x.is_a?(Foo(T))\n  'b'\nend"
  end

  it "normalizes case with Path.class to is_a?" do
    assert_expand_second "x = 1; case x; when Foo.class; 'b'; end", "if x.is_a?(Foo.class)\n  'b'\nend"
  end

  it "normalizes case with Generic.class to is_a?" do
    assert_expand_second "x = 1; case x; when Foo(T).class; 'b'; end", "if x.is_a?(Foo(T).class)\n  'b'\nend"
  end

  it "normalizes case with many expressions in when" do
    assert_expand_second "x = 1; case x; when 1, 2; 'b'; end", "if (1 === x) || (2 === x)\n  'b'\nend"
  end

  it "normalizes case with implicit call" do
    assert_expand "case x; when .foo(1); 2; end", "__temp_1 = x\nif __temp_1.foo(1)\n  2\nend"
  end

  it "normalizes case with implicit responds_to? (#3040)" do
    assert_expand "case x; when .responds_to?(:foo); 2; end", "__temp_1 = x\nif __temp_1.responds_to?(:foo)\n  2\nend"
  end

  it "normalizes case with implicit is_a? (#3040)" do
    assert_expand "case x; when .is_a?(T); 2; end", "__temp_1 = x\nif __temp_1.is_a?(T)\n  2\nend"
  end

  it "normalizes case with implicit as (#3040)" do
    assert_expand "case x; when .as(T); 2; end", "__temp_1 = x\nif __temp_1.as(T)\n  2\nend"
  end

  it "normalizes case with implicit as? (#3040)" do
    assert_expand "case x; when .as?(T); 2; end", "__temp_1 = x\nif __temp_1.as?(T)\n  2\nend"
  end

  it "normalizes case with implicit !" do
    assert_expand "case x; when .!; 2; end", "__temp_1 = x\nif !__temp_1\n  2\nend"
  end

  it "normalizes case with assignment" do
    assert_expand "case x = 1; when 2; 3; end", "x = 1\nif 2 === x\n  3\nend"
  end

  it "normalizes case with assignment wrapped by paren" do
    assert_expand "case (x = 1); when 2; 3; end", "x = 1\nif 2 === x\n  3\nend"
  end

  it "normalizes case without value" do
    assert_expand "case when 2; 3; when 4; 5; end", "if 2\n  3\nelse\n  if 4\n    5\n  end\nend"
  end

  it "normalizes case without value with many expressions in when" do
    assert_expand "case when 2, 9; 3; when 4; 5; end", "if 2 || 9\n  3\nelse\n  if 4\n    5\n  end\nend"
  end

  it "normalizes case with nil to is_a?" do
    assert_expand_second "x = 1; case x; when nil; 'b'; end", "if x.is_a?(::Nil)\n  'b'\nend"
  end

  it "normalizes case with multiple expressions" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {2, 3}; 4; end", "if (2 === x) && (3 === y)\n  4\nend"
  end

  it "normalizes case with multiple expressions and types" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {Int32, Float64}; 4; end", "if x.is_a?(Int32) && y.is_a?(Float64)\n  4\nend"
  end

  it "normalizes case with multiple expressions and implicit obj" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {.foo, .bar}; 4; end", "if x.foo && y.bar\n  4\nend"
  end

  it "normalizes case with multiple expressions and comma" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {2, 3}, {4, 5}; 6; end", "if ((2 === x) && (3 === y)) || ((4 === x) && (5 === y))\n  6\nend"
  end

  it "normalizes case with multiple expressions with underscore" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {2, _}; 4; end", "if 2 === x\n  4\nend"
  end

  it "normalizes case with multiple expressions with all underscores" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {_, _}; 4; end", "if true\n  4\nend"
  end

  it "normalizes case with multiple expressions with all underscores twice" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when {_, _}, {_, _}; 4; end", "if true\n  4\nend"
  end

  it "normalizes case with multiple expressions and non-tuple" do
    assert_expand_second "x, y = 1, 2; case {x, y}; when 1; 4; end", "if 1 === {x, y}\n  4\nend"
  end

  it "normalizes case without when and else" do
    assert_expand "case x; end", "x\nnil"
  end

  it "normalizes case without when but else" do
    assert_expand "case x; else; y; end", "x\ny"
  end

  it "normalizes case without cond, when and else" do
    assert_expand "case; end", ""
  end

  it "normalizes case without cond, when but else" do
    assert_expand "case; else; y; end", "y"
  end

  it "normalizes case with Path.class to is_a? (in)" do
    assert_expand_second "x = 1; case x; in Foo.class; 'b'; end", "if x.is_a?(Foo.class)\n  'b'\nelse\n  raise \"unreachable\"\nend"
  end
end
