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
    assert_expand_second "x = 1; case x; when 1, 2; 'b'; end", "if 1 === x || 2 === x\n  'b'\nend"
  end

  it "normalizes case with implicit call" do
    assert_expand "case x; when .foo(1); 2; end", "__temp_1 = x\nif __temp_1.foo(1)\n  2\nend"
  end

  it "normalizes case with assignment" do
    assert_expand "case x = 1; when 2; 3; end", "x = 1\nif 2 === x\n  3\nend"
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
end
