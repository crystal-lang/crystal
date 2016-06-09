require "../../spec_helper"

describe "Type inference: struct" do
  it "types struct declaration" do
    assert_type("
      struct Foo
      end
      Foo
      ") do
      str = types["Foo"].as(NonGenericClassType)
      str.struct?.should be_true
      str.metaclass
    end
  end

  it "types generic struct declaration" do
    assert_type("
      struct Foo(T)
      end
      Foo(Int32)
      ") do
      str = types["Foo"].as(GenericClassType)
      str.struct?.should be_true

      str_inst = str.instantiate([int32] of TypeVar)
      str_inst.struct?.should be_true
      str_inst.metaclass
    end
  end

  it "allows struct to participate in virtual" do
    assert_type("
      abstract struct Foo
      end

      struct Bar < Foo
      end

      struct Baz < Foo
      end

      Bar.new || Baz.new
      ") { types["Foo"].virtual_type! }
  end

  %w(Value Struct Int Float).each do |type|
    it "doesn't make virtual for #{type}" do
      assert_type("
        struct Foo < #{type}
        end

        struct Bar < #{type}
        end

        Foo.new || Bar.new
        ") { union_of(types["Foo"], types["Bar"]) }
    end
  end

  it "can't be nilable" do
    assert_type("
      struct Foo
      end

      Foo.new || nil
      ") do
      type = nilable types["Foo"]
      type.should_not be_a(NilableType)
      type
    end
  end

  it "can't extend struct from class" do
    assert_error "
      struct Foo < Reference
      end
      ", "can't make struct 'Foo' inherit class 'Reference'"
  end

  it "can't extend class from struct" do
    assert_error "
      struct Foo
      end

      class Bar < Foo
      end
      ", "can't make class 'Bar' inherit struct 'Foo'"
  end

  it "can't reopen as different type" do
    assert_error "
      struct Foo
      end

      class Foo
      end
      ", "Foo is not a class, it's a struct"
  end

  it "errors on recursive struct" do
    assert_error %(
      struct Test
        def initialize(@test : Test?)
        end
      end

      Test.new(Test.new(nil))
      ),
      "recursive struct Test detected: `@test : Test?`"
  end

  it "errors on recursive struct inside module" do
    assert_error %(
      struct Foo::Test
        def initialize(@test : Foo::Test?)
        end
      end

      Foo::Test.new(Foo::Test.new(nil))
      ),
      "recursive struct Foo::Test detected: `@test : Foo::Test?`"
  end

  it "errors on recursive generic struct inside module" do
    assert_error %(
      struct Foo::Test(T)
        def initialize(@test : Foo::Test(T)?)
        end
      end

      Foo::Test(Int32).new(Foo::Test(Int32).new(nil))
      ),
      "recursive struct Foo::Test(Int32) detected: `@test : Foo::Test(Int32)?`"
  end

  it "errors on mutually recursive struct" do
    assert_error %(
      struct Foo
        def initialize(@bar : Bar?)
        end
      end

      struct Bar
        def initialize(@foo : Foo?)
        end
      end

      Foo.new(Bar.new(nil))
      Bar.new(Foo.new(nil))
      ),
      "recursive struct Foo detected: `@bar : Bar?` -> `@foo : Foo?`"
  end

  it "can't extend struct from non-abstract struct" do
    assert_error %(
      struct A
      end

      struct B < A
      end
      ),
      "can't extend non-abstract struct A"
  end

  it "unifies type to virtual type" do
    assert_type(%(
      abstract struct Foo
      end

      struct Bar < Foo
      end

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value
      )) { types["Foo"].virtual_type! }
  end

  it "doesn't error if method is not found in abstract type" do
    assert_type(%(
      abstract struct Foo
      end

      struct Bar < Foo
        def foo
          1
        end
      end

      struct Baz < Foo
        def foo
          'a'
        end
      end

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value = Baz.new
      ptr.value.foo
      )) { union_of(int32, char) }
  end

  it "can cast to base abstract struct" do
    assert_type(%(
      abstract struct Foo
      end

      struct Bar < Foo
        def foo
          1
        end
      end

      Bar.new as Foo
      )) { types["Foo"].virtual_type! }
  end
end
