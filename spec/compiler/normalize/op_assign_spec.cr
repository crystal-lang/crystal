require "../../spec_helper"

describe "Normalize: op assign" do
  ["+", "-", "*", "&+", "&-", "&*"].each do |op|
    it "normalizes var #{op}=" do
      node = assert_normalize "a = 1; a #{op}= 2", "a = 1\na = a #{op} 2"
      call = node.as(Expressions).expressions[1].as(Assign).value.as(Call)
      assert_name_location call, 1, 10
      call.name_size.should eq(op.size + 1)
    end
  end

  it "normalizes var ||=" do
    assert_normalize "a = 1; a ||= 2", "a = 1\na || (a = 2)"
  end

  it "normalizes var &&=" do
    assert_normalize "a = 1; a &&= 2", "a = 1\na && (a = 2)"
  end

  it "normalizes exp.value +=" do
    node = assert_normalize "a.b += 1", "__temp_1 = a\n__temp_1.b = __temp_1.b + 1"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[0],
      1, 5
    assert_name_sizes node.as(Expressions).expressions[1].as(Call), 2
  end

  it "normalizes exp.value ||=" do
    node = assert_normalize "a.b ||= 1", "__temp_1 = a\n__temp_1.b || (__temp_1.b = 1)"
    assert_name_sizes node.as(Expressions).expressions[1].as(Or), 3
  end

  it "normalizes exp.value &&=" do
    node = assert_normalize "a.b &&= 1", "__temp_1 = a\n__temp_1.b && (__temp_1.b = 1)"
    assert_name_sizes node.as(Expressions).expressions[1].as(And), 3
  end

  it "normalizes var.value +=" do
    node = assert_normalize "a = 1; a.b += 2", "a = 1\na.b = a.b + 2"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[0],
      1, 12
    assert_name_sizes node.as(Expressions).expressions[1].as(Call), 2
  end

  it "normalizes @var.value +=" do
    node = assert_normalize "@a.b += 2", "@a.b = @a.b + 2"
    assert_name_location node.as(Call).args[0],
      1, 6
    assert_name_sizes node.as(Call), 2
  end

  it "normalizes @@var.value +=" do
    node = assert_normalize "@@a.b += 2", "@@a.b = @@a.b + 2"
    assert_name_location node.as(Call).args[0],
      1, 7
    assert_name_sizes node.as(Call), 2
  end

  it "normalizes exp[value] +=" do
    node = assert_normalize "a[b, c] += 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2] = __temp_3[__temp_1, __temp_2] + 1"
    assert_name_location node.as(Expressions).expressions[3].as(Call).args[2],
      1, 9
    assert_name_sizes node.as(Expressions).expressions[3].as(Call), 2
  end

  it "normalizes exp[value] ||=" do
    node = assert_normalize "a[b, c] ||= 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2]? || (__temp_3[__temp_1, __temp_2] = 1)"
    assert_name_sizes node.as(Expressions).expressions[3].as(Or), 3
  end

  it "normalizes exp[value] &&=" do
    node = assert_normalize "a[b, c] &&= 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2]? && (__temp_3[__temp_1, __temp_2] = 1)"
    assert_name_sizes node.as(Expressions).expressions[3].as(And), 3
  end

  it "normalizes exp[0] +=" do
    node = assert_normalize "a[0] += 1", "__temp_2 = a\n__temp_2[0] = __temp_2[0] + 1"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[1],
      1, 6
    assert_name_sizes node.as(Expressions).expressions[1].as(Call), 2
  end

  it "normalizes var[0] +=" do
    node = assert_normalize "a = 1; a[0] += 1", "a = 1\na[0] = a[0] + 1"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[1],
      1, 13
    assert_name_sizes node.as(Expressions).expressions[1].as(Call), 2
  end

  it "normalizes @var[0] +=" do
    node = assert_normalize "@a[0] += 1", "@a[0] = @a[0] + 1"
    assert_name_location node.as(Call).args[1],
      1, 7
    assert_name_sizes node.as(Call), 2
  end

  it "normalizes @@var[0] +=" do
    node = assert_normalize "@@a[0] += 1", "@@a[0] = @@a[0] + 1"
    assert_name_location node.as(Call).args[1],
      1, 8
    assert_name_sizes node.as(Call), 2
  end

  it "normalizes with filename" do
    assert_normalize "a[b, c] += 1", <<-CRYSTAL, filename: "foo.cr"
      __temp_cd6ae5dd_1 = b
      __temp_cd6ae5dd_2 = c
      __temp_cd6ae5dd_3 = a
      __temp_cd6ae5dd_3[__temp_cd6ae5dd_1, __temp_cd6ae5dd_2] = __temp_cd6ae5dd_3[__temp_cd6ae5dd_1, __temp_cd6ae5dd_2] + 1
      CRYSTAL

    assert_normalize "a[b, c] += 1", <<-CRYSTAL, filename: "bar.cr"
      __temp_fbcf3d84_1 = b
      __temp_fbcf3d84_2 = c
      __temp_fbcf3d84_3 = a
      __temp_fbcf3d84_3[__temp_fbcf3d84_1, __temp_fbcf3d84_2] = __temp_fbcf3d84_3[__temp_fbcf3d84_1, __temp_fbcf3d84_2] + 1
      CRYSTAL
  end
end

private def assert_name_location(node, line_number, column_number, spec_file = __FILE__, spec_line = __LINE__)
  name_location = node.name_location.should_not be_nil, file: spec_file, line: spec_line
  name_location.line_number.should eq(line_number), file: spec_file, line: spec_line
  name_location.column_number.should eq(column_number), file: spec_file, line: spec_line
end

# Asserts the size of every call generated from an `OpAssign`: the setter, the
# operator call and the getter (`a.b = a.b + 1`), or both sides of `||=`/`&&=`.
private def assert_name_sizes(node : Call, size, spec_file = __FILE__, spec_line = __LINE__)
  node.name_size.should eq(size), file: spec_file, line: spec_line
  op_call = node.args.last.as(Call)
  op_call.name_size.should eq(size), file: spec_file, line: spec_line
  op_call.obj.as(Call).name_size.should eq(size), file: spec_file, line: spec_line
end

private def assert_name_sizes(node : BinaryOp, size, spec_file = __FILE__, spec_line = __LINE__)
  node.left.as(Call).name_size.should eq(size), file: spec_file, line: spec_line
  node.right.as(Call).name_size.should eq(size), file: spec_file, line: spec_line
end
