require "../../spec_helper"

describe "Semantic: ReferenceStorage" do
  it "errors if T is a struct type" do
    assert_error <<-CRYSTAL, "can't instantiate ReferenceStorage(T) with T = Foo (T must be a reference type)"
      struct Foo
        @x = 1
      end

      ReferenceStorage(Foo)
      CRYSTAL
  end

  it "errors if T is a value type" do
    assert_error <<-CRYSTAL, "can't instantiate ReferenceStorage(T) with T = Int32 (T must be a reference type)"
      ReferenceStorage(Int32)
      CRYSTAL
  end

  it "errors if T is a union type" do
    assert_error <<-CRYSTAL, "can't instantiate ReferenceStorage(T) with T = (Bar | Foo) (T must be a reference type)"
      class Foo
      end

      class Bar
      end

      ReferenceStorage(Foo | Bar)
      CRYSTAL
  end

  it "errors if T is a nilable type" do
    assert_error <<-CRYSTAL, "can't instantiate ReferenceStorage(T) with T = (Foo | Nil) (T must be a reference type)"
      class Foo
      end

      ReferenceStorage(Foo?)
      CRYSTAL
  end
end
