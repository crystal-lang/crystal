require "../../spec_helper"

describe "Normalize: case" do
  it "normalizes case with call" do
    assert_normalize "case x; when 1; 'b'; when 2; 'c'; else; 'd'; end", "__temp_1 = x\nif 1 === __temp_1\n  'b'\nelse\n  if 2 === __temp_1\n    'c'\n  else\n    'd'\n  end\nend"
  end

  it "normalizes case with var in cond" do
    assert_normalize "x = 1; case x; when 1; 'b'; end", "x = 1\nif 1 === x\n  'b'\nend"
  end

  it "normalizes case with Path to is_a?" do
    assert_normalize "x = 1; case x; when Foo; 'b'; end", "x = 1\nif x.is_a?(Foo)\n  'b'\nend"
  end

  it "normalizes case with generic to is_a?" do
    assert_normalize "x = 1; case x; when Foo(T); 'b'; end", "x = 1\nif x.is_a?(Foo(T))\n  'b'\nend"
  end

  it "normalizes case with many expressions in when" do
    assert_normalize "x = 1; case x; when 1, 2; 'b'; end", "x = 1\nif if __temp_1 = 1 === x\n  __temp_1\nelse\n  2 === x\nend\n  'b'\nend"
  end

  it "normalizes case with implicit call" do
    assert_normalize "case x; when .foo(1); 2; end", "__temp_1 = x\nif __temp_1.foo(1)\n  2\nend"
  end

  it "normalizes case with assignment" do
    assert_normalize "case x = 1; when 2; 3; end", "x = 1\nif 2 === x\n  3\nend"
  end

  it "normalizes case without value" do
    assert_normalize "case when 2; 3; when 4; 5; end", "if 2\n  3\nelse\n  if 4\n    5\n  end\nend"
  end

  it "normalizes case without value with many expressions in when" do
    assert_normalize "case when 2, 9; 3; when 4; 5; end", "if if __temp_1 = 2\n  __temp_1\nelse\n  9\nend\n  3\nelse\n  if 4\n    5\n  end\nend"
  end
end
