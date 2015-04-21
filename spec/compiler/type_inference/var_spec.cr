require "../../spec_helper"

include Crystal

describe "Type inference: var" do
  it "types an assign" do
    input = parse "a = 1"
    result = infer_type input
    mod = result.program
    node = result.node as Assign
    expect(node.target.type).to eq(mod.int32)
    expect(node.value.type).to eq(mod.int32)
    expect(node.type).to eq(mod.int32)
  end

  it "types a variable" do
    input = parse "a = 1; a"
    result = infer_type input
    mod = result.program
    node = result.node as Expressions
    expect(node.last.type).to eq(mod.int32)
    expect(node.type).to eq(mod.int32)
  end

  it "reports undefined local variable or method" do
    assert_error "
      def foo
        a = something
      end

      def bar
        foo
      end

      bar
    ", "undefined local variable or method 'something'"
  end

  assert_syntax_error "a += 1",
                      "'+=' before definition of 'a'"

  it "reports read before assignment" do
    assert_error "a = a + 1",
      "undefined local variable or method 'a'"
  end

  it "reports there's no self" do
    assert_error "self", "there's no self in this scope"
  end

  assert_syntax_error "self = 1",
                      "can't change the value of self"

  it "reports variable always nil" do
    assert_error "1 == 2 ? (a = 1) : a",
      "read before definition of 'a'"
  end

  it "lets type on else side of if with a Bool | Nil union" do
    assert_type(%(
      a = (1 == 1) || nil
      a ? nil : a
      )) { nilable bool }
  end

  it "errors if declaring var that is already declared" do
    assert_error %(
      a = 1
      a :: Float64
      ),
      "variable 'a' already declared"
  end
end
