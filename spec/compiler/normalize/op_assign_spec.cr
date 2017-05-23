require "../../spec_helper"

describe "Normalize: op assign" do
  it "normalizes var +=" do
    assert_normalize "a = 1; a += 2", "a = 1\na = a + 2"
  end

  it "normalizes var ||=" do
    assert_normalize "a = 1; a ||= 2", "a = 1\na || (a = 2)"
  end

  it "normalizes var &&=" do
    assert_normalize "a = 1; a &&= 2", "a = 1\na && (a = 2)"
  end

  it "normalizes exp.value +=" do
    assert_normalize "a.b += 1", "__temp_1 = a\n__temp_1.b = __temp_1.b + 1"
  end

  it "normalizes exp.value ||=" do
    assert_normalize "a.b ||= 1", "__temp_1 = a\n__temp_1.b || (__temp_1.b = 1)"
  end

  it "normalizes exp.value &&=" do
    assert_normalize "a.b &&= 1", "__temp_1 = a\n__temp_1.b && (__temp_1.b = 1)"
  end

  it "normalizes var.value +=" do
    assert_normalize "a = 1; a.b += 2", "a = 1\na.b = a.b + 2"
  end

  it "normalizes @var.value +=" do
    assert_normalize "@a.b += 2", "@a.b = @a.b + 2"
  end

  it "normalizes @@var.value +=" do
    assert_normalize "@@a.b += 2", "@@a.b = @@a.b + 2"
  end

  it "normalizes exp[value] +=" do
    assert_normalize "a[b, c] += 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2] = __temp_3[__temp_1, __temp_2] + 1"
  end

  it "normalizes exp[value] ||=" do
    assert_normalize "a[b, c] ||= 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2]? || (__temp_3[__temp_1, __temp_2] = 1)"
  end

  it "normalizes exp[value] &&=" do
    assert_normalize "a[b, c] &&= 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2]? && (__temp_3[__temp_1, __temp_2] = 1)"
  end

  it "normalizes exp[0] +=" do
    assert_normalize "a[0] += 1", "__temp_2 = a\n__temp_2[0] = __temp_2[0] + 1"
  end

  it "normalizes var[0] +=" do
    assert_normalize "a = 1; a[0] += 1", "a = 1\na[0] = a[0] + 1"
  end

  it "normalizes @var[0] +=" do
    assert_normalize "@a[0] += 1", "@a[0] = @a[0] + 1"
  end

  it "normalizes @@var[0] +=" do
    assert_normalize "@@a[0] += 1", "@@a[0] = @@a[0] + 1"
  end
end
