require "../../spec_helper"

describe "Semantic: enum" do
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

  it "disallows None value when defined with @[Flags]" do
    assert_error %(
      @[Flags]
      enum Foo
        None
      end
      ),
      "flags enum can't contain None or All members"
  end

  it "disallows All value when defined with @[Flags]" do
    assert_error %(
      @[Flags]
      enum Foo
        All = 50
      end
      ),
      "flags enum can't contain None or All members"
  end

  it "doesn't error when defining a non-flags enum with None or All" do
    assert_type(%(
      enum Foo
        None
        All = 50
      end

      Foo::None.value
      )) { int32 }
  end

  it "doesn't error when defining a flags enum in a lib with None or All" do
    assert_type(%(
      lib Lib
        @[Flags]
        enum Foo
          None
          All = 50
        end
      end

      Lib::Foo::None.value
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
      enum Foo
        A

        def meth
          puts @value
        end
      end

      Foo::A.meth
      ),
      "can't use instance variables inside enums (at enum Foo)"
  end

  it "marks as flags with base type (#2185)" do
    result = semantic(%(
      @[Flags]
      enum SomeFacts : UInt8
        AppleLover
        PearLover
        CoolDude
      end

      SomeFacts::AppleLover
      ))
    enum_type = result.program.types["SomeFacts"].as(EnumType)
    enum_type.has_attribute?("Flags").should be_true
  end

  it "can use macro expression inside enum" do
    assert_type(%(
      enum Foo
        {{ "A".id }}
      end

      Foo::A
      )) { types["Foo"] }
  end

  it "can use macro for inside enum" do
    assert_type(%(
      enum Foo
        {% for name in %w(A B C) %}
          {{name.id}}
        {% end %}
      end

      Foo::A
      )) { types["Foo"] }
  end

  it "errors if inheriting Enum (#3592)" do
    assert_error %(
      struct Foo < Enum
      end
      ),
      "can't inherit Enum. Use the enum keyword to define enums"
  end

  it "errors on enum without members (#3447)" do
    assert_error %(
      enum Foo
      end
      ),
      "enum Foo must have at least one member"
  end

  it "errors if declaring type inside enum (#3127)" do
    assert_error %(
      enum Foo
        A
      end

      class Foo::Bar
      end
      ),
      "can't declare type inside enum Foo"
  end

  it "errors if declaring type inside enum, nested (#3127)" do
    assert_error %(
      enum Foo
        A
      end

      class Foo::Bar::Baz
      end
      ),
      "can't declare type inside enum"
  end
end
