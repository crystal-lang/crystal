require "../../spec_helper"

describe "Semantic: extern struct" do
  it "declares extern struct with no constructor" do
    assert_type(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "declares with constructor" do
    assert_type(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def initialize(@x)
        end

        def foo
          @x
        end
      end

      Foo.new(1).foo
      )) { int32 }
  end

  it "overrides getter" do
    assert_type(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def x
          'a'
        end
      end

      Foo.new.x
      )) { char }
  end

  it "can be passed to C fun" do
    assert_type(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32
      end

      lib LibFoo
        fun foo(x : Foo) : Float64
      end

      LibFoo.foo(Foo.new)
      )) { float64 }
  end

  it "can include module" do
    assert_type(%(
      module Moo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      @[Extern]
      struct Foo
        include Moo
      end

      Foo.new.x
      )) { int32 }
  end

  it "errors if using non-primitive for field type" do
    assert_error %(
      class Bar
      end

      @[Extern]
      struct Foo
        @x = uninitialized Bar
      end
      ),
      "only primitive types, pointers, structs, unions, enums and tuples are allowed in extern struct declarations"
  end

  it "errors if using non-primitive for field type via module" do
    assert_error %(
      class Bar
      end

      module Moo
        @x = uninitialized Bar
      end

      @[Extern]
      struct Foo
        include Moo
      end
      ),
      "only primitive types, pointers, structs, unions, enums and tuples are allowed in extern struct declarations"
  end

  it "errors if using non-primitive type in constructor" do
    assert_error %(
      class Bar
      end

      @[Extern]
      struct Foo
        def initialize
          @x = Bar.new
        end
      end
      ),
      "only primitive types, pointers, structs, unions, enums and tuples are allowed in extern struct declarations"
  end

  it "declares extern union with no constructor" do
    assert_type(%(
      @[Extern(union: true)]
      struct Foo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "can use extern struct in lib" do
    assert_type(%(
      @[Extern]
      struct Foo
      end

      lib LibFoo
        fun foo(x : Foo) : Foo
      end

      foo = Foo.new
      LibFoo.foo(foo)
      )) { types["Foo"] }
  end

  it "can new with named args" do
    assert_type(%(
      @[Extern]
      struct A
        def initialize(@x : Int32)
        end
      end

      A.new(x: 6)
      )) { types["A"] }
  end
end
