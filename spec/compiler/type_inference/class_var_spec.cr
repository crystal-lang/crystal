require "../../spec_helper"

describe "Type inference: class var" do
  it "declares class variable" do
    assert_error %(
      class Foo
        @@x : Int32
        @@x = 1

        def self.x=(x)
          @@x = x
        end
      end

      Foo.x = true
      ),
      "class variable '@@x' of Foo must be Int32, not Bool"
  end

  it "declares class variable (2)" do
    assert_error %(
      class Foo
        @@x : Int32

        def self.x
          @@x
        end
      end

      Foo.x
      ),
      "class variable '@@x' of Foo must be Int32, not Nil"
  end
  it "types class var" do
    assert_type("
      class Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ") { int32 }
  end

  it "types class var as nil if not assigned at the top level" do
    assert_type("
      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo
      ") { nilable int32 }
  end

  it "types class var inside instance method" do
    assert_type("
      class Foo
        @@foo = 1

        def foo
          @@foo
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "types class var inside fun literal inside class" do
    assert_type("
      class Foo
        @@foo = 1
        f = -> { @@foo }
      end
      f.call
      ") { int32 }
  end

  it "says illegal attribute for class var" do
    assert_error %(
      class Foo
        @[Foo]
        @@foo
      end
      ),
      "illegal attribute"
  end

  it "says illegal attribute for class var assignment" do
    assert_error %(
      class Foo
        @[Foo]
        @@foo = 1
      end
      ),
      "illegal attribute"
  end

  it "allows self.class as type var in class body (#537)" do
    assert_type(%(
      class Bar(T)
      end

      class Foo
        @@bar = Bar(self.class).new

        def self.bar
          @@bar
        end
      end

      Foo.bar
      )) { generic_class "Bar", types["Foo"].virtual_type.metaclass }
  end

  it "errors if using self as type var but there's no self" do
    assert_error %(
      class Bar(T)
      end

      Bar(self).new
      ),
      "there's no self in this scope"
  end

  it "allows class var in primitive types (#612)" do
    assert_type("
      struct Int64
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Int64.foo
      ") { int32 }
  end

  it "errors if using class var in generic type without instance" do
    assert_error %(
      class Foo(T)
        def self.bar
          @@bar
        end
      end

      Foo.bar
      ),
      "can't use class variables in generic types"
  end

  it "errors if using class var in generic type without instance (2)" do
    assert_error %(
      class Foo(T)
        @@bar = 1
      end
      ),
      "can't use class variables in generic types"
  end

  it "errors if using class var in generic module without instance (2)" do
    assert_error %(
      module Foo(T)
        @@bar = 1
      end
      ),
      "can't use class variables in generic types"
  end

  it "types class var as nil if assigned for the first time inside method (#2059)" do
    assert_type("
      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo
      ") { nilable int32 }
  end

  it "redefines class variable type" do
    assert_type(%(
      class Foo
        @@x : Int32
        @@x : Int32 | Float64
        @@x = 1

        def self.x
          @@x
        end
      end

      Foo.x
      )) { union_of int32, float64 }
  end

  it "infers type from number literal" do
    assert_type(%(
      class Foo
        @@x = 1

        def self.x
          @@x
        end
      end

      Foo.x
      )) { int32 }
  end

  it "infers type from T.new" do
    assert_type(%(
      class Foo
        class Bar
        end

        @@x = Bar.new

        def self.x
          @@x
        end
      end

      Foo.x
      )) { types["Foo"].types["Bar"] }
  end

  it "says undefined class variable" do
    assert_error "
      class Foo
        def self.foo
          @@foo
        end
      end

      Foo.foo
      ",
      "Can't infer the type of class variable '@@foo' of Foo"
  end

  it "errors if using class variable at the top level" do
    assert_error "
      @@foo = 1
      @@foo
      ",
      "can't use class variables at the top level"
  end

  it "errors when typing a class variable inside a method" do
    assert_error %(
      def foo
        @@x : Int32
      end

      foo
      ),
      "declaring the type of a class variable must be done at the class level"
  end

  it "errors if using local variable in initializer" do
    assert_error %(
      class Foo
        @@x : Int32

        a = 1
        @@x = a
      end
      ),
      "undefined local variable or method 'a'"
  end

  it "errors on undefined constant (1)" do
    assert_error %(
      class Foo
        def self.foo
          @@x = Bar.new
        end
      end

      Foo.foo
      ),
      "undefined constant Bar"
  end

  it "errors on undefined constant (2)" do
    assert_error %(
      class Foo
        @@x = Bar.new
      end

      Foo.foo
      ),
      "undefined constant Bar"
  end

  it "infers in multiple assign for tuple type (1)" do
    assert_type(%(
      class Foo
        def self.foo
          @@x, @@y = Bar.method
        end

        def self.x
          @@x
        end
      end

      class Bar
        def self.method : {Int32, Bool}
          {1, true}
        end
      end

      Foo.x
      )) { nilable int32 }
  end

  it "errors when using Class (#2605)" do
    assert_error %(
      class Foo
        def foo(@@class : Class)
        end
      end
      ),
      "can't use Class as the type of class variable @@class of Foo, use a more specific type"
  end
end
