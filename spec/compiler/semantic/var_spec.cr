require "../../spec_helper"

include Crystal

describe "Semantic: var" do
  it "types an assign" do
    input = parse "a = 1"
    result = semantic input
    mod = result.program
    node = result.node.as(Assign)
    node.target.type.should eq(mod.int32)
    node.value.type.should eq(mod.int32)
    node.type.should eq(mod.int32)
  end

  it "types a variable" do
    input = parse "a = 1; a"
    result = semantic input
    mod = result.program
    node = result.node.as(Expressions)
    node.last.type.should eq(mod.int32)
    node.type.should eq(mod.int32)
  end

  it "types an assign with type declaration" do
    assert_type("a : Int32 = 1") { int32 }
  end

  it "reports undefined local variable or method" do
    assert_error <<-CRYSTAL, "undefined local variable or method 'something'"
      def foo
        a = something
      end

      def bar
        foo
      end

      bar
      CRYSTAL
  end

  it "reports there's no self" do
    assert_error "self", "there's no self in this scope"
  end

  it "reports variable always nil" do
    assert_error "1 == 2 ? (a = 1) : a",
      "read before assignment to local variable 'a'", inject_primitives: true
  end

  it "lets type on else side of if with a Bool | Nil union" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable bool }
      a = (1 == 1) || nil
      a ? nil : a
      CRYSTAL
  end

  it "errors if declaring var that is already declared" do
    assert_error <<-CRYSTAL, "variable 'a' already declared"
      a = 1
      a = uninitialized Float64
      CRYSTAL
  end

  it "errors if reads from underscore" do
    assert_error <<-CRYSTAL, "can't read from _"
      _
      CRYSTAL
  end

  it "declares local variable with value" do
    assert_type(<<-CRYSTAL) { int32 }
      a : Int32 = 0
      a
      CRYSTAL
  end

  it "declares local variable and then assigns it" do
    assert_type(<<-CRYSTAL) { int32 }
      a : Int32
      a = 0
      a
      CRYSTAL
  end

  it "declares local variable and immediately reads it" do
    assert_error <<-CRYSTAL, "read before assignment to local variable 'a'"
      a : Int32
      a
      CRYSTAL
  end

  it "declares local variable and assigns it with if" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a : Int32
      if 1 == 2
        a = 0
      else
        a = 1
      end
      a
      CRYSTAL
  end

  it "declares local variable but doesn't assign it in all branches" do
    assert_error <<-CRYSTAL, "type must be Int32", inject_primitives: true
      a : Int32
      if 1 == 2
        a = 0
      end
      a
      CRYSTAL
  end

  it "declares local variable and assigns wrong type" do
    assert_error <<-CRYSTAL, "type must be Int32"
      a : Int32
      a = true
      CRYSTAL
  end

  it "parse local variable as method call even if local variable is declared in call arguments" do
    assert_error <<-CRYSTAL, "undefined local variable or method 'a'"
      macro foo(x)
        {{x}}
      end
      foo a : Int32
      a
      CRYSTAL
  end

  it "errors if variable already exists" do
    assert_error <<-CRYSTAL, "variable 'a' already declared"
      a = true
      a : Int32
      CRYSTAL
  end

  it "errors if declaring generic type without type vars (with local var)" do
    assert_error <<-CRYSTAL, "can't declare variable of generic non-instantiated type Foo"
      class Foo(T)
      end

      x : Foo
      CRYSTAL
  end
end
