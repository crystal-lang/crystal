require "../../spec_helper"

private def expect_augment(before : String, after : String)
  result = semantic(before)
  result.node.to_s.should eq(after)
end

private def it_augments_for_ivar(ivar_type : String, expected_type : String)
  it "augments #{ivar_type}" do
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
  it_augments_for_ivar "Proc(Int32, Char)", "::Proc(::Int32, ::Char)"
  it_augments_for_ivar "Proc(Int32, Nil)", "::Proc(::Int32, _)"
  it_augments_for_ivar "Pointer(Void)", "::Pointer(::Void)"
  it_augments_for_ivar "Char | Int32 | String", "::Char | ::Int32 | ::String"
  it_augments_for_ivar "Char | Int32 | String", "::Char | ::Int32 | ::String"

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
end
