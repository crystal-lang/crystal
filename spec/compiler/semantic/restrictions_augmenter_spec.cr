require "../../spec_helper"

private def expect_augment(before : String, after : String)
  result = semantic(before)
  result.node.to_s.chomp.should eq(after.chomp)
end

private def expect_no_augment(code : String, flags = nil)
  result = semantic(code, flags: flags)
  result.node.to_s.chomp.should eq(code.chomp)
end

private def it_augments_for_ivar(ivar_type : String, expected_type : String, file = __FILE__, line = __LINE__)
  it "augments #{ivar_type}", file, line do
    before = <<-BEFORE
      class Foo
        @x : #{ivar_type}
        def initialize(value)
          @x = value
        end
      end
      BEFORE

    after = <<-AFTER
      class Foo
        @x : #{ivar_type}
        def initialize(value : #{expected_type})
          @x = value
        end
      end
      AFTER

    expect_augment before, after
  end
end

describe "Semantic: restrictions augmenter" do
  it_augments_for_ivar "Nil", "::Nil"
  it_augments_for_ivar "Bool", "::Bool"
  it_augments_for_ivar "Char", "::Char"
  it_augments_for_ivar "Int32", "::Int32"
  it_augments_for_ivar "Float32", "::Float32"
  it_augments_for_ivar "Symbol", "::Symbol"
  it_augments_for_ivar "String", "::String"
  it_augments_for_ivar "Array(String)", "::Array(::String)"
  it_augments_for_ivar "Tuple(Int32, Char)", "::Tuple(::Int32, ::Char)"
  it_augments_for_ivar "NamedTuple(a: Int32, b: Char)", "::NamedTuple(a: ::Int32, b: ::Char)"
  it_augments_for_ivar "Proc(Int32, Char)", "(::Int32 -> ::Char)"
  it_augments_for_ivar "Proc(Int32, Nil)", "(::Int32 -> _)"
  it_augments_for_ivar "Pointer(Void)", "::Pointer(::Void)"
  it_augments_for_ivar "StaticArray(Int32, 8)", "::StaticArray(::Int32, 8)"
  it_augments_for_ivar "Char | Int32 | String", "::Char | ::Int32 | ::String"
  it_augments_for_ivar "Char | Int32 | String", "::Char | ::Int32 | ::String"
  it_augments_for_ivar "Int32.class", "::Int32.class"
  it_augments_for_ivar "NoReturn", "::NoReturn"

  it "augments relative public type" do
    before = <<-BEFORE
      class Foo
        class Bar
          class Baz
          end
        end

        @x : Bar:: Baz

        def initialize(value)
          @x = value
        end
      end
      BEFORE

    after = <<-AFTER
      class Foo
        class Bar
          class Baz
          end
        end
        @x : Bar::Baz
        def initialize(value : ::Foo::Bar::Baz)
          @x = value
        end
      end
      AFTER

    expect_augment before, after
  end

  it "augments relative private type" do
    before = <<-BEFORE
      class Foo
        private class Bar
          class Baz
          end
        end

        @x : Bar:: Baz

        def initialize(value)
          @x = value
        end
      end
      BEFORE

    after = <<-AFTER
      class Foo
        private class Bar
          class Baz
          end
        end
        @x : Bar::Baz
        def initialize(value : Bar::Baz)
          @x = value
        end
      end
      AFTER

    expect_augment before, after
  end

  it "augments relative private type in same namespace" do
    before = <<-BEFORE
      class Foo
        private class Bar
        end
        private class Baz
          @x : Bar
          def initialize(value)
            @x = value
          end
        end
      end
      BEFORE

    after = <<-AFTER
      class Foo
        private class Bar
        end
        private class Baz
          @x : Bar
          def initialize(value : Bar)
            @x = value
          end
        end
      end
      AFTER

    expect_augment before, after
  end

  it "augments generic uninstantiated type" do
    before = <<-BEFORE
      class Foo(T)
        @x : Array(T)
        def initialize(value)
          @x = value
        end
      end
      BEFORE

    after = <<-AFTER
      class Foo(T)
        @x : Array(T)
        def initialize(value : ::Array(T))
          @x = value
        end
      end
      AFTER

    expect_augment before, after
  end

  it "augments for class var" do
    before = <<-BEFORE
      class Foo
        @@x = 1
        def self.set(value)
          @@x = value
        end
      end
      BEFORE

    after = <<-AFTER
      class Foo
        @@x = 1
        def self.set(value : ::Int32)
          @@x = value
        end
      end
      AFTER

    expect_augment before, after
  end

  it "doesn't augment if assigned inside if" do
    expect_no_augment <<-CODE
      class Foo
        @x : Int32
        def initialize(value)
          if value
            @x = value
          end
        end
      end
      CODE
  end

  it "doesn't augment if assigned inside while" do
    expect_no_augment <<-CODE
      class Foo
        @x : Int32
        def initialize(value)
          while false
            @x = value
          end
        end
      end
      CODE
  end

  it "doesn't augment if assigned inside block" do
    expect_no_augment <<-CODE
      def foo
        yield
      end
      class Foo
        @x : Int32
        def initialize(value)
          foo do
            @x = value
          end
        end
      end
      CODE
  end

  it "doesn't augment if the no_restrictions_augmenter flag is present" do
    expect_no_augment <<-CODE, flags: "no_restrictions_augmenter"
      class Foo
        @x : Int32
        def initialize(value)
          @x = value
        end
      end
      CODE
  end

  it "augments recursive alias type (#12134)" do
    before = <<-BEFORE
      alias BasicObject = Array(BasicObject) | Hash(String, BasicObject)
      class Foo
        def initialize(value = Hash(String, BasicObject).new)
          @x = value
        end
      end
      BEFORE

    after = <<-AFTER
      alias BasicObject = Array(BasicObject) | Hash(String, BasicObject)
      class Foo
        def initialize(value : ::Hash(::String, ::BasicObject) = Hash(String, BasicObject).new)
          @x = value
        end
      end
      AFTER

    expect_augment before, after
  end

  it "augments typedef" do
    before = <<-BEFORE
      lib LibFoo
        type X = Void*
      end
      class Foo
        @x : LibFoo::X
        def initialize(value)
          @x = value
        end
      end
      BEFORE

    after = <<-AFTER
      lib LibFoo
        type X = Void*
      end
      class Foo
        @x : LibFoo::X
        def initialize(value : ::LibFoo::X)
          @x = value
        end
      end
      AFTER

    expect_augment before, after
  end
end
