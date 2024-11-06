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
      ),
      "expected argument #1 to 'foo' to be Foo, not Int32"
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

  it "doesn't break assigned values in enum flags when a member has value 0 (#5767)" do
    result = semantic(%(
      @[Flags]
      enum Foo
        OtherNone = 0
        Bar
        Baz
      end
      ))
    enum_type = result.program.types["Foo"].as(EnumType)
    enum_type.types["OtherNone"].as(Const).value.should eq(NumberLiteral.new("0", :i32))
    enum_type.types["Bar"].as(Const).value.should eq(NumberLiteral.new("1", :i32))
    enum_type.types["Baz"].as(Const).value.should eq(NumberLiteral.new("2", :i32))
  end

  it "disallows redefining None to non-0 for @[Flags] enum" do
    assert_error %(
      @[Flags]
      enum Foo
        None = 42
        Dummy
      end
      ),
      "flags enum can't redefine None member to non-0"

    assert_error %(
      @[Flags]
      enum Foo
        None    # 1
        Dummy
      end
      ),
      "flags enum can't redefine None member to non-0"
  end

  it "allows redefining None to 0 for @[Flags] enum" do
    assert_type(%(
      @[Flags]
      enum Foo
        None = 0
        Dummy
      end

      Foo::None.value
      )) { int32 }
  end

  it "disallows All value for @[Flags] enum" do
    assert_error %(
      @[Flags]
      enum Foo
        All = 50
      end
      ),
      "flags enum can't redefine All member"
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
          Dummy
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
    annotation_type = result.program.types["Flags"].as(AnnotationType)
    enum_type.annotation(annotation_type).should_not be_nil
  end

  it "reopens enum without base type (1)" do
    assert_no_errors <<-CRYSTAL
      enum Foo
        X
      end

      enum Foo
      end
      CRYSTAL
  end

  it "reopens enum without base type (2)" do
    assert_no_errors <<-CRYSTAL
      enum Foo : UInt8
        X
      end

      enum Foo
      end
      CRYSTAL
  end

  it "reopens enum with same base type (1)" do
    assert_no_errors <<-CRYSTAL
      enum Foo
        X
      end

      enum Foo : Int32
      end
      CRYSTAL
  end

  it "reopens enum with same base type (2)" do
    assert_no_errors <<-CRYSTAL
      enum Foo : UInt8
        X
      end

      enum Foo : UInt8
      end
      CRYSTAL
  end

  it "errors if reopening enum with different base type (1)" do
    assert_error <<-CRYSTAL, "enum Foo's base type is Int32, not UInt8"
      enum Foo
        X
      end

      enum Foo : UInt8
      end
      CRYSTAL
  end

  it "errors if reopening enum with different base type (2)" do
    assert_error <<-CRYSTAL, "enum Foo's base type is UInt8, not UInt16"
      enum Foo : UInt8
        X
      end

      enum Foo : UInt16
      end
      CRYSTAL
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

    assert_error %(
      @[Flags]
      enum Foo
        None = 0
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

  it "attaches annotation to enum method (#6690)" do
    result = semantic(%(
      enum Foo
        X

        @[AlwaysInline]
        def bar
        end
      end
      ))

    method = result.program.types["Foo"].lookup_first_def("bar", block: false).not_nil!
    method.always_inline?.should be_true
  end

  it "errors if defining initialize in Enum (#7238)" do
    assert_error %(
      enum Foo
        FOO = 1

        def initialize
        end
      end
      ),
      "enums can't define an `initialize` method, try using `def self.new`"
  end

  it "can redefine Enum.new" do
    assert_type(%(
      enum Foo
        FOO = 1

        def self.new(x : Int32)
          "hello"
        end
      end

      Foo.new(1)
      )) { string }
  end

  it "gives error on enum overflow" do
    assert_error %(
      enum Foo : Int8
        #{Array.new(129) { |i| "V#{i + 1}" }.join "\n"}
      end
      ),
      "value of enum member V129 would overflow the base type Int8"
  end

  it "gives error on flags enum overflow" do
    assert_error %(
      @[Flags]
      enum Foo : UInt8
        #{Array.new(9) { |i| "V#{i + 1}" }.join "\n"}
      end
      ),
      "value of enum member V9 would overflow the base type UInt8"
  end

  it "gives error on enum overflow after a member with value" do
    assert_error <<-CRYSTAL, "value of enum member B would overflow the base type Int32"
      enum Foo
        A = 0x7FFFFFFF
        B
      end
      CRYSTAL
  end

  it "gives error on signed flags enum overflow after a member with value" do
    assert_error <<-CRYSTAL, "value of enum member B would overflow the base type Int32"
      @[Flags]
      enum Foo
        A = 0x40000000
        B
      end
      CRYSTAL
  end

  it "gives error on unsigned flags enum overflow after a member with value" do
    assert_error <<-CRYSTAL, "value of enum member B would overflow the base type UInt32"
      @[Flags]
      enum Foo : UInt32
        A = 0x80000000
        B
      end
      CRYSTAL
  end

  it "doesn't overflow when going from negative to zero (#7874)" do
    assert_no_errors <<-CRYSTAL
      enum Nums
        Zero  = -2
        One
        Two
      end
      CRYSTAL
  end

  it "doesn't overflow on flags member (#7877)" do
    assert_no_errors <<-CRYSTAL
      @[Flags]
      enum Filter
        A = 1 << 29
        B
      end
      CRYSTAL
  end

  it "doesn't visit enum members generated by macros twice (#10104)" do
    result = semantic(%(
      enum Foo
        A = 1

        {% begin %}
          def foo
          end
        {% end %}
      end
      ))
    a_def = result.program.types["Foo"].lookup_defs("foo").first
    a_def.previous.should be_nil
  end
end
