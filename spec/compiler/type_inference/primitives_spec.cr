require "../../spec_helper"

describe "Type inference: primitives" do
  it "types a bool" do
    assert_type("false") { bool }
  end

  it "types an int32" do
    assert_type("1") { int32 }
  end

  it "types a int64" do
    assert_type("1_i64") { int64 }
  end

  it "types a float32" do
    assert_type("2.3_f32") { float32 }
  end

  it "types a float64" do
    assert_type("2.3_f64") { float64 }
  end

  it "types a char" do
    assert_type("'a'") { char }
  end

  it "types a symbol" do
    assert_type(":foo") { symbol }
  end

  it "types a string" do
    assert_type("\"foo\"") { string }
  end

  it "types nil" do
    assert_type("nil") { |mod| mod.nil }
  end

  it "types nop" do
    assert_type("") { |mod| mod.nil }
  end

  it "types an expression" do
    assert_type("1; 'a'") { char }
  end

  it "types 1 + 2" do
    assert_type("1 + 2") { int32 }
  end

  it "types sizeof" do
    assert_type("sizeof(Float64)") { int32 }
  end

  it "types instance_sizeof" do
    assert_type("instance_sizeof(Reference)") { int32 }
  end

  it "errors when comparing void (#225)" do
    assert_error %(
      lib Foo
        fun foo
      end

      Foo.foo == 1
      ), "undefined method '==' for Void"
  end

  it "correctly types first hash from type vars (bug)" do
    assert_type(%(
      class Hash(K, V)
      end

      def foo(x : K, y : V)
        {} of K => V
      end

      x = foo 1, 'a'
      y = foo 'a', 1
      x
      )) { (types["Hash"] as GenericClassType).instantiate([int32, char] of TypeVar) }
  end
end
