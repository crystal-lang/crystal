require "../../spec_helper"

describe "Semantic: sizeof" do
  it "types sizeof" do
    assert_type("sizeof(Float64)") { int32 }
  end

  it "types sizeof NoReturn (missing type) (#5717)" do
    assert_type("x = nil; x ? sizeof(typeof(x)) : 1") { int32 }
  end

  it "types instance_sizeof" do
    assert_type("instance_sizeof(Reference)") { int32 }
  end

  it "types instance_sizeof NoReturn (missing type) (#5717)" do
    assert_type("x = nil; x ? instance_sizeof(typeof(x)) : 1") { int32 }
  end

  it "errors on sizeof uninstantiated generic type (#6415)" do
    assert_error "sizeof(Array)", "can't take sizeof uninstantiated generic type Array(T)"
  end

  it "gives error if using instance_sizeof on something that's not a class" do
    assert_error "instance_sizeof(Int32)", "Int32 is not a class, it's a struct"
  end

  it "gives error if using instance_sizeof on a generic type without type vars" do
    assert_error "instance_sizeof(Array)", "can't take instance_sizeof uninstantiated generic type Array(T)"
  end
end
