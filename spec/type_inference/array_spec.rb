require 'spec_helper'

describe 'Type inference: array' do
  it "types empty array literal" do
    assert_type("[]") { ArrayType.new }
  end

  it "types array literal" do
    assert_type("[].length") { int }
  end

  it "types array literal of int" do
    assert_type("[1, 2, 3]") { ArrayType.of(int) }
  end

  it "types array literal of union" do
    assert_type("[1, 2.5]") { ArrayType.of([int, float].union) }
  end

  it "types array getter" do
    assert_type("a = [1, 2]; a[0]") { int }
  end

  it "types array setter" do
    assert_type("a = [1, 2]; a[0] = 1") { int }
  end

  it "types array union" do
    assert_type("a = [1, 2]; a[0] = 1; a[1] = 2.5; a") { ArrayType.of([int, float].union) }
  end

  it "types array push" do
    assert_type("a = []; a.push 1") { ArrayType.of(int) }
  end

  it "types array <<" do
    assert_type("a = []; a << 1") { ArrayType.of(int) }
  end

  it "types recursive array" do
    assert_type("a = []; a << a") { a = ArrayType.new; a.element_type_var.type = a; a }
  end

  it "types recursive array with length" do
    assert_type("a = []; a << a; a.length; a") { a = ArrayType.new; a.element_type_var.type = a; a }
  end

  it "types Array.new" do
    assert_type("Array.new(2, Object.new)") { ArrayType.of(ObjectType.new('Object')) }
  end

  it "types array of array" do
    assert_type("a = [[], []]; a[0] << 1; a") { ArrayType.of(ArrayType.of(int)) }
  end

  it "types literal more than two elements" do
    assert_type(%Q(
      class Foo
        def value=(value)
          @value = value
        end
      end

      f = Foo.alloc
      g = Foo.alloc
      h = Foo.alloc
      a = [f, g, h]

      h.value = 1
      a
    )) { ArrayType.of(UnionType.new(ObjectType.new('Foo'), ObjectType.new('Foo').with_var('@value', int))) }
  end

  it "simplify dispatch call to array member" do
    assert_type(%Q(
      a = [[], []]
      s = a[1].to_s
    )) { string }
  end

  pending "recalculate target_def of array obj" do
    input = parse '[[]][0].push 1'
    mod = infer_type input
    input.obj.target_def.body.type.should eq(ArrayType.of(mod.int))
  end
end
