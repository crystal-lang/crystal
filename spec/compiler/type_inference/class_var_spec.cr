require "../../spec_helper"

describe "Type inference: class var" do
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

  it "types class var as nil" do
    assert_type("
      class Foo
        def self.foo
          @@foo
        end
      end

      Foo.foo
      ") { |mod| mod.nil }
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

  it "types class var as nil if assigned for the first time inside method" do
    assert_type("
      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo
      ") { |mod| union_of(mod.nil, int32) }
  end

  it "types class var of program" do
    assert_type("
      @@foo = 1
      @@foo
      ") { int32 }
  end

  it "types class var inside fun literal" do
    assert_type("
      @@foo = 1
      f = -> { @@foo }
      f.call
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
      )) { (types["Bar"] as GenericClassType).instantiate([types["Foo"].virtual_type!.metaclass] of TypeVar) }
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

  it "types class var in generic instance type (#726)" do
    assert_type(%(
      class Foo(T)
        def self.bar
          @@bar ||= 'a'
        end
      end

      Foo(Int32).bar
      )) { char }
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
      "can't use class variable with generic types, only with generic types instances"
  end

  it "errors if using class var in generic type without instance (2)" do
    assert_error %(
      class Foo(T)
        @@bar = 1
      end
      ),
      "can't use class variable with generic types, only with generic types instances"
  end

  it "errors if using class var in generic module without instance (2)" do
    assert_error %(
      module Foo(T)
        @@bar = 1
      end
      ),
      "can't use class variable with generic types, only with generic types instances"
  end
end
