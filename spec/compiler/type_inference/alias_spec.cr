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
    expect(aliased_type.union_types[0]).to eq(mod.int32)
    expect(aliased_type.union_types[1]).to eq(foo_alias)
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

  it "allows using generic type of recursive alias as restriction (#488)" do
    assert_type(%(
      class Foo(T)
      end

      alias Rec = String | Foo(Rec)

      def command(request : Foo(Rec))
        1
      end

      foo = Foo(Rec).new
      command(foo)
      )) { int32 }
  end

  it "resolves type through alias (#563)" do
    assert_type(%(
      module A
        Foo = 1
      end

      alias B = A
      B::Foo
      )) { int32 }
  end

  it "errors if trying to resolve type of recursive alias" do
    assert_error %(
      class Foo(T)
        A = 1
      end

      alias Rec = Int32 | Foo(Rec)

      Rec::A
      ),
      "undefined constant Rec::A"
  end

  %w(class module struct).each do |type|
    it "reopens #{type} through alias" do
      assert_type(%(
        #{type} Foo
        end

        alias Bar = Foo

        #{type} Bar
          def self.bar
            1
          end
        end

        Bar.bar
        )) { int32 }
    end
  end

  %w(class struct).each do |type|
    it "inherits #{type} through alias" do
      assert_type(%(
        #{type} Parent
        end

        alias Alias = Parent

        #{type} Child  < Alias
          def self.bar
            1
          end
        end

        Child.bar
        )) { int32 }
    end
  end

  it "includes module through alias" do
    assert_type(%(
      module Moo
        def bar
          1
        end
      end

      alias Alias = Moo

      class Foo
        include Alias
      end

      Foo.new.bar
      )) { int32 }
  end
end
