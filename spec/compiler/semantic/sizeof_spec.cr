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
    assert_error %(
      instance_sizeof(Int32)
      ),
      "instance_sizeof can only be used with a class, but Int32 is a struct"
  end

  it "gives error if using instance_sizeof on a struct" do
    assert_error %(
      struct Foo
      end

      instance_sizeof(Foo)
      ),
      "instance_sizeof can only be used with a class, but Foo is a struct"
  end

  it "gives error if using instance_sizeof on an abstract struct (#11855)" do
    assert_error %(
      abstract struct Foo
      end

      instance_sizeof(Foo)
      ),
      "instance_sizeof can only be used with a class, but Foo is a struct"
  end

  it "gives error if using instance_sizeof on an abstract struct with multiple subtypes (#11855)" do
    assert_error %(
      abstract struct Foo
      end

      struct Child1 < Foo
      end

      struct Child2 < Foo
      end

      instance_sizeof(Foo)
      ),
      "instance_sizeof can only be used with a class, but Foo is a struct"
  end

  it "gives error if using instance_sizeof on a module" do
    assert_error %(
      module Moo
      end

      instance_sizeof(Moo)
      ),
      "instance_sizeof can only be used with a class, but Moo is a module"
  end

  it "gives error if using instance_sizeof on a metaclass" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Foo.class is a metaclass"
      class Foo
      end

      instance_sizeof(Foo.class)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on a generic type without type vars" do
    assert_error "instance_sizeof(Array)", "can't take instance_sizeof uninstantiated generic type Array(T)"
  end

  it "gives error if using instance_sizeof on a union type (#8349)" do
    assert_error "instance_sizeof(Int32 | Bool)",
      "instance_sizeof can only be used with a class, but (Bool | Int32) is a union"
  end
end
