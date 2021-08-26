require "../../spec_helper"

describe "Normalize: multi assign" do
  it "normalizes n to n" do
    assert_expand "a, b, c = 1, 2, 3", "__temp_1 = 1\n__temp_2 = 2\n__temp_3 = 3\na = __temp_1\nb = __temp_2\nc = __temp_3"
  end

  it "normalizes 1 to n" do
    assert_expand_second "d = 1\na, b, c = d", "__temp_1 = d\na = __temp_1[0]\nb = __temp_1[1]\nc = __temp_1[2]"
  end

  it "normalizes n to n with []" do
    assert_expand_third "a = 1; b = 2; a[0], b[1] = 2, 3", "__temp_1 = 2\n__temp_2 = 3\na[0] = __temp_1\nb[1] = __temp_2"
  end

  it "normalizes 1 to n with []" do
    assert_expand_third "a = 1; b = 2; a[0], b[1] = 2", "__temp_1 = 2\na[0] = __temp_1[0]\nb[1] = __temp_1[1]"
  end

  it "normalizes n to n with call" do
    assert_expand_third "a = 1; b = 2; a.foo, b.bar = 2, 3", "__temp_1 = 2\n__temp_2 = 3\na.foo = __temp_1\nb.bar = __temp_2"
  end

  it "normalizes 1 to n with call" do
    assert_expand_third "a = 1; b = 2; a.foo, b.bar = 2", "__temp_1 = 2\na.foo = __temp_1[0]\nb.bar = __temp_1[1]"
  end

  context "preview_multi_assign" do
    it "normalizes 1 to n" do
      assert_expand_second "d = 1\na, b, c = d", <<-CR,
        __temp_1 = d
        if __temp_1.size != 3
          ::raise("Multiple assignment count mismatch")
        end
        a = __temp_1[0]
        b = __temp_1[1]
        c = __temp_1[2]
        CR
        flags: "preview_multi_assign"
    end

    it "normalizes 1 to n with []" do
      assert_expand_third "a = 1; b = 2; a[0], b[1] = 2", <<-CR,
        __temp_1 = 2
        if __temp_1.size != 2
          ::raise("Multiple assignment count mismatch")
        end
        a[0] = __temp_1[0]
        b[1] = __temp_1[1]
        CR
        flags: "preview_multi_assign"
    end

    it "normalizes 1 to n with call" do
      assert_expand_third "a = 1; b = 2; a.foo, b.bar = 2", <<-CR,
        __temp_1 = 2
        if __temp_1.size != 2
          ::raise("Multiple assignment count mismatch")
        end
        a.foo = __temp_1[0]
        b.bar = __temp_1[1]
        CR
        flags: "preview_multi_assign"
    end
  end
end
