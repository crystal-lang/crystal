require "../../spec_helper"

describe "Semantic: const" do
  it "types a constant" do
    input = parse("CONST = 1").as(Assign)
    semantic input
    input.target.type?.should be_nil # Don't type value until needed
  end

  it "types a constant reference" do
    assert_type("CONST = 1; CONST") { int32 }
  end

  it "types a nested constant" do
    assert_type("class Foo; A = 1; end; Foo::A") { int32 }
  end

  it "types a constant using Path" do
    assert_type(%(
      Foo::Bar = 1

      Foo::Bar
      )) { int32 }
  end

  it "types a nested constant using Path" do
    assert_type(%(
      class Foo
        Bar::Baz = 1
      end

      Foo::Bar::Baz
      )) { int32 }
  end

  it "types a nested type with same name" do
    assert_type(%(
      class Foo
        class Foo
          A = 1
        end
      end

      Foo::Foo::A
      )) { int32 }
  end

  it "creates container module if not exist when using Path" do
    assert_type(%(
      Foo::Bar = 1
      Foo
    )) do
      foo = types["Foo"]
      foo.module?.should be_true
      foo.metaclass
    end
  end

  it "keeps type of container when using Path" do
    assert_type(%(
      class Foo
      end

      Foo::Const = 1
      Foo
    )) do
      foo = types["Foo"]
      foo.class?.should be_true
      foo.metaclass
    end

    assert_type(%(
      struct Foo
      end

      Foo::Const = 1
      Foo
    )) do
      foo = types["Foo"]
      foo.struct?.should be_true
      foo.metaclass
    end

    assert_type(%(
      module Foo
      end

      Foo::Const = 1
      Foo
    )) do
      foo = types["Foo"]
      foo.module?.should be_true
      foo.metaclass
    end
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

  it "finds current type before parents (#4086)" do
    assert_type(%(
      class Foo
        class Bar
          class Baz < Foo
            def self.foo
              Baz.new.foo
            end

            def foo
              1
            end
          end
        end

        class Baz
        end
      end

      Foo::Bar::Baz.foo
      )) { int32 }
  end

  it "doesn't count parent types as current type" do
    assert_type(%(
      class Foo
      end

      class Bar
        class Foo
          def foo
            1
          end
        end

        class Baz < Foo
          def self.bar
            Foo.new
          end
        end
      end

      Bar::Baz.bar.foo
      )) { int32 }
  end

  it "finds current type only for first path item (1)" do
    assert_error %(
      class Foo
        def self.foo
          Foo::Foo
        end
      end

      Foo.foo
      ),
      "undefined constant Foo::Foo"
  end

  it "finds current type only for first path item (2)" do
    assert_error %(
      class Foo
        class Foo
        end

        def self.foo
          Foo::Foo
        end
      end

      Foo.foo
      ),
      "undefined constant Foo::Foo"
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

  ["nil", "true", "1", "'a'", %("foo"), "+ 1", "- 2", "~ 2",
   "1 + 2", "1 + ZED", "ZED - 1", "ZED * 2", "ZED // 2",
   "1 &+ ZED", "ZED &- 1", "ZED &* 2"].each do |node|
    it "doesn't errors if constant depends on another one defined later through method, but constant is simple (#{node})" do
      assert_no_errors <<-CRYSTAL, inject_primitives: true
        ZED = 10

        struct Int32
          def +; 0; end
          def ~; 0; end
          def -; 0; end
          def //(other); 0; end
        end

        CONST1 = foo
        CONST2 = #{node}

        def foo
          CONST2
        end

        CONST1
        CRYSTAL
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

  it "errors if can't infer constant type (#3240, #3948)" do
    assert_error %(
      A = A.b
      A
      ),
      "can't infer type of constant A"
  end

  it "errors if using constant as generic type (#3240)" do
    assert_error %(
      Foo = Foo(Int32).new
      Foo
      ),
      "Foo is not a type, it's a constant"
  end

  it "errors if using const in type declaration" do
    assert_error %(
      A = 1

      class Foo
        @x : A
      end
      ),
      "A is not a type, it's a constant"
  end

  it "errors if using const in uninitialized" do
    assert_error %(
      A = 1

      x = uninitialized A
      ),
      "A is not a type, it's a constant"
  end

  it "errors if using const in var declaration" do
    assert_error %(
      A = 1

      x : A
      ),
      "A is not a type, it's a constant"
  end

  it "errors if using const in restriction" do
    assert_error %(
      A = 1

      def foo(x : A)
      end

      foo(1)
      ),
      "A is not a type, it's a constant"
  end

  it "errors if using const in proc notation parameter type" do
    assert_error <<-CRYSTAL, "A is not a type, it's a constant"
      A = 1

      x : A ->
      CRYSTAL
  end

  it "errors if using const in proc notation return type" do
    assert_error <<-CRYSTAL, "A is not a type, it's a constant"
      A = 1

      x : -> A
      CRYSTAL
  end

  it "errors if using return inside constant value (#5391)" do
    assert_error %(
      class Foo
        A = begin
          return if 1 == 2
        end
      end

      Foo::A
      ),
      "can't return from constant", inject_primitives: true
  end

  it "errors if constant has NoReturn type (#6139)" do
    assert_error %(
      lib LibFoo
        fun foo : NoReturn
      end

      FOO = LibFoo.foo

      FOO
      ),
      "constant FOO has illegal type NoReturn"
  end
end
