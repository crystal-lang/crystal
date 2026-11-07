require "../../spec_helper"

describe "Normalize: op assign" do
  ["+", "-", "*", "&+", "&-", "&*"].each do |op|
    it "normalizes var #{op}=" do
      node = assert_normalize "a = 1; a #{op}= 2", "a = 1\na = a #{op} 2"
      assert_name_location node.as(Expressions).expressions[1].as(Assign).value,
        1, 10
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
  end

  it "normalizes exp.value ||=" do
    assert_normalize "a.b ||= 1", "__temp_1 = a\n__temp_1.b || (__temp_1.b = 1)"
  end

  it "normalizes exp.value &&=" do
    assert_normalize "a.b &&= 1", "__temp_1 = a\n__temp_1.b && (__temp_1.b = 1)"
  end

  it "normalizes var.value +=" do
    node = assert_normalize "a = 1; a.b += 2", "a = 1\na.b = a.b + 2"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[0],
      1, 12
  end

  it "normalizes @var.value +=" do
    node = assert_normalize "@a.b += 2", "@a.b = @a.b + 2"
    assert_name_location node.as(Call).args[0],
      1, 6
  end

  it "normalizes @@var.value +=" do
    node = assert_normalize "@@a.b += 2", "@@a.b = @@a.b + 2"
    assert_name_location node.as(Call).args[0],
      1, 7
  end

  it "normalizes exp[value] +=" do
    node = assert_normalize "a[b, c] += 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2] = __temp_3[__temp_1, __temp_2] + 1"
    assert_name_location node.as(Expressions).expressions[3].as(Call).args[2],
      1, 9
  end

  it "normalizes exp[value] ||=" do
    assert_normalize "a[b, c] ||= 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2]? || (__temp_3[__temp_1, __temp_2] = 1)"
  end

  it "normalizes exp[value] &&=" do
    assert_normalize "a[b, c] &&= 1", "__temp_1 = b\n__temp_2 = c\n__temp_3 = a\n__temp_3[__temp_1, __temp_2]? && (__temp_3[__temp_1, __temp_2] = 1)"
  end

  it "normalizes exp[0] +=" do
    node = assert_normalize "a[0] += 1", "__temp_2 = a\n__temp_2[0] = __temp_2[0] + 1"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[1],
      1, 6
  end

  it "normalizes var[0] +=" do
    node = assert_normalize "a = 1; a[0] += 1", "a = 1\na[0] = a[0] + 1"
    assert_name_location node.as(Expressions).expressions[1].as(Call).args[1],
      1, 13
  end

  it "normalizes @var[0] +=" do
    node = assert_normalize "@a[0] += 1", "@a[0] = @a[0] + 1"
    assert_name_location node.as(Call).args[1],
      1, 7
  end

  it "normalizes @@var[0] +=" do
    node = assert_normalize "@@a[0] += 1", "@@a[0] = @@a[0] + 1"
    assert_name_location node.as(Call).args[1],
      1, 8
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

private class CallCollector < Crystal::Visitor
  getter calls = [] of Crystal::Call

  def visit(node : Crystal::Call)
    @calls << node
    true
  end

  def visit(node : Crystal::ASTNode)
    true
  end
end

private def normalized_calls(source)
  collector = CallCollector.new
  Program.new.normalize(Parser.parse(source)).accept(collector)
  collector.calls
end

describe "Normalize: op assign name size" do
  {
    "a **= 1", "a.foo **= 1", "a.foo ||= 1", "a.foo &&= 1", "a.foo += 1",
    "a[0] **= 1", "a[0] ||= 1", "a[0] &&= 1", "a[0] += 1",
  }.each do |source|
    it "uses the size of the operator for #{source.inspect}" do
      source = "a = 1; #{source}"
      operator = source.split(' ')[-2]
      column = source.rindex!(operator) + 1

      calls = normalized_calls(source).select { |call| call.name_location.try(&.column_number) == column }
      calls.should_not be_empty
      calls.map(&.name_size).uniq!.should eq([operator.size])
    end
  end
end
