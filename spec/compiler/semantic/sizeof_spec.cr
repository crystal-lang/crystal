require "../../spec_helper"

describe "Semantic: sizeof" do
  {% for name in %w(sizeof instance_sizeof alignof instance_alignof).map(&.id) %}
    it "types {{ name }}" do
      assert_type("{{ name }}(Reference)") { int32 }
    end

    it "types {{ name }} NoReturn (missing type) (#5717)" do
      assert_type("x = nil; x ? {{ name }}(typeof(x)) : 1") { int32 }
    end
  {% end %}

  it "errors on sizeof uninstantiated generic type (#6415)" do
    assert_error "sizeof(Array)", "can't take size of uninstantiated generic type Array(T)"
  end

  it "gives error if using instance_sizeof on something that's not a class" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Int32 is a struct"
      instance_sizeof(Int32)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on a struct" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Foo is a struct"
      struct Foo
      end

      instance_sizeof(Foo)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on an abstract struct (#11855)" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Foo is a struct"
      abstract struct Foo
      end

      instance_sizeof(Foo)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on an abstract struct with multiple subtypes (#11855)" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Foo is a struct"
      abstract struct Foo
      end

      struct Child1 < Foo
      end

      struct Child2 < Foo
      end

      instance_sizeof(Foo)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on a module" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Moo is a module"
      module Moo
      end

      instance_sizeof(Moo)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on a metaclass" do
    assert_error <<-CRYSTAL, "instance_sizeof can only be used with a class, but Foo.class is a metaclass"
      class Foo
      end

      instance_sizeof(Foo.class)
      CRYSTAL
  end

  it "gives error if using instance_sizeof on a generic type without type vars" do
    assert_error "instance_sizeof(Array)", "can't take instance size of uninstantiated generic type Array(T)"
  end

  it "gives error if using instance_sizeof on a union type (#8349)" do
    assert_error "instance_sizeof(Int32 | Bool)",
      "instance_sizeof can only be used with a class, but (Bool | Int32) is a union"
  end
end
