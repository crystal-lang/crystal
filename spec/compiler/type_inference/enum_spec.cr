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
      ), "mno overload matches 'foo' with types Int32"
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
    assert_error  %(
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
    assert_error  %(
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
end
