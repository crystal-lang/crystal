#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: const" do
  it "types a constant" do
    input = parse "A = 1"
    assert_type input, Assign

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
      class Int32
        FOO = 'a'
      end

      def foo(x : U)
        U::FOO
      end

      foo 1
      ") { char }
  end
end
