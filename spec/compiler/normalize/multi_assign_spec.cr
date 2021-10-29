require "../../spec_helper"

describe "Normalize: multi assign" do
  it "normalizes n to n" do
    assert_expand "a, b, c = 1, 2, 3", <<-CR
      __temp_1 = 1
      __temp_2 = 2
      __temp_3 = 3
      a = __temp_1
      b = __temp_2
      c = __temp_3
      CR
  end

  it "normalizes 1 to n" do
    assert_expand_second "d = 1; a, b, c = d", <<-CR
      __temp_1 = d
      a = __temp_1[0]
      b = __temp_1[1]
      c = __temp_1[2]
      CR
  end

  it "normalizes n to n with []" do
    assert_expand_third "a = 1; b = 2; a[0], b[1] = 2, 3", <<-CR
      __temp_1 = 2
      __temp_2 = 3
      a[0] = __temp_1
      b[1] = __temp_2
      CR
  end

  it "normalizes 1 to n with []" do
    assert_expand_third "a = 1; b = 2; a[0], b[1] = 2", <<-CR
      __temp_1 = 2
      a[0] = __temp_1[0]
      b[1] = __temp_1[1]
      CR
  end

  it "normalizes n to n with call" do
    assert_expand_third "a = 1; b = 2; a.foo, b.bar = 2, 3", <<-CR
      __temp_1 = 2
      __temp_2 = 3
      a.foo = __temp_1
      b.bar = __temp_2
      CR
  end

  it "normalizes 1 to n with call" do
    assert_expand_third "a = 1; b = 2; a.foo, b.bar = 2", <<-CR
      __temp_1 = 2
      a.foo = __temp_1[0]
      b.bar = __temp_1[1]
      CR
  end

  it "normalizes m to n, with splat on left-hand side, splat is empty" do
    assert_expand_third "a = 1; b = 2; *a[0], b.foo, c = 3, 4", <<-CR
      __temp_1 = ::Tuple.new
      __temp_2 = 3
      __temp_3 = 4
      a[0] = __temp_1
      b.foo = __temp_2
      c = __temp_3
      CR
  end

  it "normalizes m to n, with splat on left-hand side, splat is non-empty" do
    assert_expand_third "a = 1; b = 2; a[0], *b.foo, c = 3, 4, 5, 6, 7", <<-CR
      __temp_1 = 3
      __temp_2 = ::Tuple.new(4, 5, 6)
      __temp_3 = 7
      a[0] = __temp_1
      b.foo = __temp_2
      c = __temp_3
      CR
  end

  it "normalizes 1 to n, with splat on left-hand side" do
    assert_expand_third "c = 1; d = 2; a, b, *c.foo, d[0], e, f = 3", <<-CR
      __temp_1 = 3
      if __temp_1.size < 5
        ::raise(::IndexError.new("Multiple assignment count mismatch"))
      end
      a = __temp_1[0]
      b = __temp_1[1]
      c.foo = __temp_1[2..-4]
      d[0] = __temp_1[-3]
      e = __temp_1[-2]
      f = __temp_1[-1]
      CR
  end

  it "normalizes 1 to n, with splat on left-hand side, splat before other targets" do
    assert_expand "*a, b, c, d = 3", <<-CR
      __temp_1 = 3
      a = __temp_1[0..-4]
      b = __temp_1[-3]
      c = __temp_1[-2]
      d = __temp_1[-1]
      CR
  end

  it "normalizes 1 to n, with splat on left-hand side, splat after other targets" do
    assert_expand "a, b, c, *d = 3", <<-CR
      __temp_1 = 3
      a = __temp_1[0]
      b = __temp_1[1]
      c = __temp_1[2]
      d = __temp_1[3..-1]
      CR
  end
end
