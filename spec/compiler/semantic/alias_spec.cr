require "../../spec_helper"

describe "Semantic: alias" do
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

    foo = mod.types["Foo"].as(GenericClassType)
    a = mod.types["Alias"].as(AliasType)

    foo_alias = foo.instantiate([a] of TypeVar)

    aliased_type = a.aliased_type.as(UnionType)
    union_types = aliased_type.union_types.sort_by &.to_s
    union_types[0].should eq(foo_alias)
    union_types[1].should eq(mod.int32)
  end

  it "allows defining recursive fun aliases" do
    result = assert_type(%(
      alias Alias = Alias -> Alias
      1
      )) { int32 }

    mod = result.program

    a = mod.types["Alias"].as(AliasType)
    aliased_type = a.aliased_type.as(ProcInstanceType)

    aliased_type.should eq(mod.proc_of(a, a))
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
      alias Alias = String
      alias Alias = Int32
      ),
      "alias Alias is already defined"
  end

  it "errors if alias is already defined as another type" do
    assert_error %(
      alias String = Int32
      ),
      "can't alias String because it's already defined as a class"
  end

  it "errors if defining infinite recursive alias" do
    assert_error %(
      alias Alias = Alias
      Alias
      ),
      "infinite recursive definition of alias Alias"
  end

  it "errors if defining infinite recursive alias in union" do
    assert_error %(
      alias Alias = Int32 | Alias
      Alias
      ),
      "infinite recursive definition of alias Alias"
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
      module Moo
        Foo = 1
      end

      alias Alias = Moo
      Alias::Foo
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
        abstract #{type} Parent
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

  it "errors if declares alias inside if" do
    assert_error %(
      if 1 == 2
        alias Foo = Int32
      end
      ),
      "can't declare alias dynamically"
  end

  it "errors if trying to use typeof in alias" do
    assert_error %(
      alias Foo = typeof(1)
      ),
      "can't use 'typeof' here"
  end

  it "can use .class in alias (#2835)" do
    assert_type(%(
      alias Foo = Int32.class | String.class
      Foo
      )) { union_of(int32.metaclass, string.metaclass).metaclass }
  end

  it "uses constant in alias (#3259)" do
    assert_type(%(
      CONST = 10
      alias Alias = UInt8[CONST]
      Alias
      )) { static_array_of(uint8, 10).metaclass }
  end

  it "uses constant in alias with math (#3259)" do
    assert_type(%(
      CONST = 2*3 + 4
      alias Alias = UInt8[CONST]
      Alias
      )) { static_array_of(uint8, 10).metaclass }
  end

  it "looks up alias for macro resolution (#3548)" do
    assert_type(%(
      class Foo
        class Bar
          def self.baz
            1
          end
        end
      end

      alias Baz = Foo

      Baz::Bar.baz
      )) { int32 }
  end

  it "finds type through alias (#4645)" do
    assert_type(%(
      module FooBar
        module Foo
          A = 10
        end

        module Bar
          include Foo
        end
      end

      class Baz
        alias Bar = FooBar::Bar

        def test
          Bar::A
        end
      end

      Baz.new.test
      )) { int32 }
  end

  it "doesn't find type parameter in alias (#3502)" do
    assert_error %(
      class A(T)
        alias B = A(T)
      end
      ),
      "undefined constant T"
  end
end
