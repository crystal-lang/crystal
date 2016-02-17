require "../../spec_helper"

describe "Type inference: enum" do
  it "types enum" do
    assert_type(%(
      enum Foo
        A = 1
      end
      Foo::A
      )) { types["Foo"] }
  end

  it "types enum value" do
    assert_type(%(
      enum Foo
        A = 1
      end
      Foo::A.value
      )) { int32 }
  end

  it "disallows implicit conversion of int to enum" do
    assert_error %(
      enum Foo
        A = 1
      end

      def foo(x : Foo)
      end

      foo 1
      ), "no overload matches 'foo' with type Int32"
  end

  it "finds method in enum type" do
    assert_type(%(
      struct Enum
        def foo
          1
        end
      end

      enum Foo
        A = 1
      end

      Foo::A.foo
      )) { int32 }
  end

  it "finds class method in enum type" do
    assert_type(%(
      struct Enum
        def self.foo
          1
        end
      end

      enum Foo
        A = 1
      end

      Foo.foo
      )) { int32 }
  end

  it "errors if using a name twice" do
    assert_error %(
      enum Foo
        A
        A
      end
      ),
      "enum 'Foo' already contains a member named 'A'"
  end

  it "creates enum from value" do
    assert_type(%(
      enum Foo
        A
        B
      end

      Foo.new(1)
      )) { types["Foo"] }
  end

  it "defines method on enum" do
    assert_type(%(
      enum Foo
        A
        B

        def foo
          1
        end
      end

      Foo::A.foo
      )) { int32 }
  end

  it "defines class method on enum" do
    assert_type(%(
      enum Foo
        A
        B

        def self.foo
          1
        end
      end

      Foo.foo
      )) { int32 }
  end

  it "reopens an enum" do
    assert_type(%(
      enum Foo
        A
        B
      end

      enum Foo
        def foo
          1
        end
      end

      Foo::A.foo
      )) { int32 }
  end

  it "errors if reopen but not enum" do
    assert_error %(
      class Foo
      end

      enum Foo
        A
        B
      end
      ),
      "Foo is not a enum, it's a class"
  end

  it "errors if reopen and tries to define constant" do
    assert_error %(
      enum Foo
        A
        B
      end

      enum Foo
        C
      end
      ),
      "can't reopen enum and add more constants to it"
  end

  it "has None value when defined as @[Flags]" do
    assert_type(%(
      @[Flags]
      enum Foo
        A
        B
      end

      Foo::None.value
      )) { int32 }
  end

  it "has All value when defined as @[Flags]" do
    assert_type(%(
      @[Flags]
      enum Foo
        A
        B
      end

      Foo::All.value
      )) { int32 }
  end

  it "doesn't error when defining a method for an enum with flags" do
    assert_type(%(
      @[Flags]
      enum Foo
        A
        B

        def foo
          self
        end
      end

      Foo::A.foo
      )) { types["Foo"] }
  end

  it "allows class vars in enum" do
    assert_type(%(
      enum Foo
        A

        @@class_var = 1

        def self.class_var
          @@class_var
        end
      end

      Foo.class_var
      )) { int32 }
  end

  it "errors if invoking private enum method" do
    assert_error %(
      enum Foo
        A

        private def foo
          1
        end
      end

      Foo::A.foo
      ),
      "private method 'foo' called for Foo"
  end

  it "errors if enum value is too big for type (#678)" do
    assert_error %(
      enum Foo
        A = 2147486719
      end
      ),
      "invalid Int32: 2147486719"
  end

  it "errors if using instance var inside enum (#991)" do
    assert_error %(
      enum X
        A

        def meth
          puts @value
        end
      end

      X::A.meth
      ),
      "can't use instance variables inside enums (at enum X)"
  end
end
