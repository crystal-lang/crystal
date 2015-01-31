require "../../spec_helper"

describe "Type inference: const" do
  it "types a constant" do
    input = parse("A = 1") as Assign
    result = infer_type input
    mod = result.program
    input.target.type?.should be_nil # Don't type value until needed
  end

  it "types a constant reference" do
    assert_type("A = 1; A") { int32 }
  end

  it "types a nested constant" do
    assert_type("class B; A = 1; end; B::A") { int32 }
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
      A = 1

      class Foo
        A = 2.5

        def foo
          A
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
      A = 2.5

      class B
        A = 1

        def foo
          ::A
        end
      end

      B.new.foo
      ") { float64 }
  end

  it "types a global constant reference in static method" do
    assert_type("
      A = 2.5

      class B
        A = 1

        def self.foo
          A
        end
      end

      B.foo
      ") { int32 }
  end

  it "doesn't share variables with global scope" do
    assert_error "a = 1; A = a; A",
      "undefined local variable or method 'a'"
  end

  it "finds const from restriction" do
    assert_type("
      struct Int32
        FOO = 'a'
      end

      def foo(x : U)
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
      module A
        CONSTANT = true
      end

      module B
        include A
      end

      B::CONSTANT
      )) { bool }
  end

  it "finds constant in class that extends class (#205)" do
    assert_type(%(
      class A
        CONSTANT = true
      end

      class B < A
      end

      B::CONSTANT
      )) { bool }
  end

  it "detects recursive constant definition" do
    assert_error %(
      A = B
      B = A

      A
      ),
      "constant A requires initialization of B, which is initialized later. Initialize B before A"
  end

  it "errors if constant depends on another one defined later through method" do
    assert_error %(
      A = foo
      B = 1

      def foo
        B
      end

      A
      ), "constant A requires initialization of B, which is initialized later. Initialize B before A"
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

  it "errors if constant depends on a global initialized later" do
    assert_error %(
      A = foo
      $b = 1

      def foo
        $b
      end

      A
      ), "constant A requires initialization of $b, which is initialized later. Initialize $b before A"
  end

  it "doesn't error if constant depends on a global var that is never initialized" do
    assert_type(%(
      A = foo

      def foo
        $b
      end

      A
      )) { |mod| mod.nil }
  end
end
