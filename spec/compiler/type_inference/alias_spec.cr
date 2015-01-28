require "../../spec_helper"

describe "type inference: alias" do
  it "resolves alias type" do
    assert_type("
      alias Alias = Int32
      Alias
      ") { types["Int32"].metaclass }
  end

  it "works with alias type as restriction" do
    assert_type("
      alias Alias = Int32

      def foo(x : Alias)
        x
      end

      foo 1
      ") { int32 }
  end

  it "allows using alias type as generic type" do
    assert_type("
      class Foo(T)
        def initialize(x : T)
          @x = x
        end

        def x
          @x
        end
      end

      alias Num = Int32 | Float64

      f = Foo(Num).new(1)
      g = Foo(Num).new(1.5)
      1
      ") { int32 }
  end

  it "allows defining recursive aliases" do
    result = assert_type("
      class Foo(T)
      end

      alias Alias = Int32 | Foo(Alias)
      1
      ") { int32 }
    mod = result.program

    foo = mod.types["Foo"] as GenericClassType
    a = mod.types["Alias"] as AliasType

    foo_alias = foo.instantiate([a] of TypeVar)

    aliased_type = a.aliased_type as UnionType
    aliased_type.union_types[0].should eq(mod.int32)
    aliased_type.union_types[1].should eq(foo_alias)
  end

  it "allows recursive array with alias" do
    assert_type(%(
      alias Type = Nil | Pointer(Type)
      p = Pointer(Type).malloc(1_u64)
      1
      )) { int32 }
  end

  it "errors if alias already defined" do
    assert_error %(
      alias A = String
      alias A = Int32
      ),
      "alias A is already defined"
  end

  it "errors if alias is already defined as another type" do
    assert_error %(
      alias String = Int32
      ),
      "can't alias String because it's already defined as a class"
  end

  it "errors if defining infinite recursive alias" do
    assert_error %(
      alias A = A
      ),
      "infinite recursive definition of alias A"
  end

  it "errors if defining infinite recursive alias in union" do
    assert_error %(
      alias A = Int32 | A
      ),
      "infinite recursive definition of alias A"
  end
end
