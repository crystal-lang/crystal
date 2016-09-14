require "../../spec_helper"

describe "Semantic: const" do
  it "types a constant" do
    input = parse("CONST = 1").as(Assign)
    result = semantic input
    mod = result.program
    input.target.type?.should be_nil # Don't type value until needed
  end

  it "types a constant reference" do
    assert_type("CONST = 1; CONST") { int32 }
  end

  it "types a nested constant" do
    assert_type("class Foo; A = 1; end; Foo::A") { int32 }
  end

  it "types a constant inside a def" do
    assert_type("
      class Foo
        A = 1

        def foo
          A
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "finds nearest constant first" do
    assert_type("
      CONST = 1

      class Foo
        CONST = 2.5

        def foo
          CONST
        end
      end

      Foo.new.foo
      ") { float64 }
  end

  it "finds current type first" do
    assert_type("
      class Foo
        class Bar
          def self.foo
            Bar.new.foo
          end

          def foo
            1
          end
        end
      end

      Foo::Bar.foo
      ") { int32 }
  end

  it "types a global constant reference in method" do
    assert_type("
      FOO = 2.5

      class Bar
        FOO = 1

        def foo
          ::FOO
        end
      end

      Bar.new.foo
      ") { float64 }
  end

  it "types a global constant reference in static method" do
    assert_type("
      CONST = 2.5

      class Bar
        CONST = 1

        def self.foo
          CONST
        end
      end

      Bar.foo
      ") { int32 }
  end

  it "doesn't share variables with global scope" do
    assert_error "a = 1; CONST = a; CONST",
      "undefined local variable or method 'a'"
  end

  it "finds const from restriction" do
    assert_type("
      struct Int32
        FOO = 'a'
      end

      def foo(x : U) forall U
        U::FOO
      end

      foo 1
      ") { char }
  end

  it "doesn't crash with const used in initialize (bug)" do
    assert_type("
      COCO = init_coco

      def init_coco
        1
      end

      class Foo
        def initialize
          COCO
        end
      end

      Foo.new

      COCO
      ") { int32 }
  end

  it "finds constant in module that includes module (#205)" do
    assert_type(%(
      module Foo
        CONSTANT = true
      end

      module Moo
        include Foo
      end

      Moo::CONSTANT
      )) { bool }
  end

  it "finds constant in class that extends class (#205)" do
    assert_type(%(
      class Foo
        CONSTANT = true
      end

      class Bar < Foo
      end

      Bar::CONSTANT
      )) { bool }
  end

  ["nil", "true", "1", "'a'", %("foo"), "+ 1", "- 2", "~ 2", "1 + 2", "1 + ZED"].each do |node|
    it "doesn't errors if constant depends on another one defined later through method, but constant is simple (#{node})" do
      semantic(%(
        ZED = 10

        struct Int32
          def +; 0; end
          def ~; 0; end
          def -; 0; end
        end

        CONST1 = foo
        CONST2 = #{node}

        def foo
          CONST2
        end

        CONST1
        ))
    end
  end

  it "doesn't error if using c enum" do
    assert_type(%(
      lib LibC
        enum Foo
          A = 1
        end
      end

      LibC::Foo::A
      )) { types["LibC"].types["Foo"] }
  end

  it "errors on dynamic constant assignment inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        CONST = 1
      end
      ),
      "can't declare constant dynamically"
  end

  it "errors on dynamic constant assignment inside if" do
    assert_error %(
      if 1 == 1
        CONST = 1
      end
      ),
      "can't declare constant dynamically"
  end

  it "can use constant defined later (#2906)" do
    assert_type(%(
      FOO = Foo.new

      class Foo
        A = Bar.new

        def initialize
          A
        end
      end

      class Bar
      end

      FOO
      )) { types["Foo"] }
  end
end
