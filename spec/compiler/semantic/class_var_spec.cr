require "../../spec_helper"

describe "Semantic: class var" do
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
      "class variable '@@x' of Foo is not nilable (it's Int32) so it must have an initializer"
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

  it "types class var inside proc literal inside class" do
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

  it "declares class var in generic class" do
    assert_type(%(
      class Foo(T)
        @@bar = 1

        def bar
          @@bar
        end
      end

      Foo(Int32).new.bar
      )) { int32 }
  end

  it "declares class var in generic module" do
    assert_type(%(
      module Foo(T)
        @@bar = 1

        def self.bar
          @@bar
        end
      end

      Foo.bar
      )) { int32 }
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

  it "gives correct error when trying to use Int as a class variable type" do
    assert_error %(
      class Foo
        @@x : Int
      end
      ),
      "can't use Int as the type of a class variable yet, use a more specific type"
  end

  it "can find class var in subclass" do
    assert_type(%(
      class Foo
        @@var = 1
      end

      class Bar < Foo
        def self.var
          @@var
        end
      end

      Bar.var
      )) { int32 }
  end

  it "can find class var through included module" do
    assert_type(%(
      module Moo
        @@var = 1
      end

      class Bar
        include Moo

        def self.var
          @@var
        end
      end

      Bar.var
      )) { int32 }
  end

  it "errors if redefining class var type in subclass" do
    assert_error %(
      class Foo
        @@x : Int32
      end

      class Bar < Foo
        @@x : Float64
      end
      ),
      "class variable '@@x' of Bar is already defined as Int32 in Foo"
  end

  it "errors if redefining class var type in subclass, with guess" do
    assert_error %(
      class Foo
        @@x = 1
      end

      class Bar < Foo
        @@x = 'a'
      end
      ),
      "class variable '@@x' of Bar is already defined as Int32 in Foo"
  end

  it "errors if redefining class var type in included module" do
    assert_error %(
      module Moo
        @@x : Int32
      end

      class Bar
        include Moo

        @@x : Float64
      end
      ),
      "class variable '@@x' of Bar is already defined as Int32 in Moo"
  end

  it "declares uninitialized (#2935)" do
    assert_type(%(
      class Foo
        @@x = uninitialized Int32

        def self.x
          @@x
        end
      end

      Foo.x
      )) { int32 }
  end

  it "doesn't error if accessing class variable before defined (#2941)" do
    assert_type(%(
      class Bar
        @@x : Baz = Foo.x

        def self.x
          @@x
        end
      end

      class Foo
        @@x = Baz.new

        def self.x
          @@x
        end
      end

      class Baz
        def y
          1
        end
      end

      Bar.x.y
      )) { int32 }
  end

  it "doesn't error on recursive depdendency if var is nilable (#2943)" do
    assert_type(%(
      class Foo
        @@foo : Int32?
        @@foo = Foo.bar

        def self.bar
          @@foo
        end

        def self.foo
          @@foo
        end
      end

      Foo.foo
      )) { nilable int32 }
  end

  it "types as nilable if doesn't have initializer" do
    assert_type(%(
      class Foo
        def self.x
          @@x = 1
          @@x
        end
      end

      Foo.x
      )) { nilable int32 }
  end

  it "errors if class variable not nilable without initializer" do
    assert_error %(
      class Foo
        @@foo : Int32
      end
      ),
      "class variable '@@foo' of Foo is not nilable (it's Int32) so it must have an initializer"
  end

  it "can assign to class variable if this type can be up-casted to ancestors class variable type (#4869)" do
    assert_type(%(
      class Foo
        @@x : Int32?

        def self.x
          @@x
        end
      end

      class Bar < Foo
        @@x = 42
      end

      Bar.x
      )) { nilable(int32) }
  end
end
