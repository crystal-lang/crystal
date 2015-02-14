require "../../spec_helper"

describe "Type inference: def" do
  it "types a call with an int" do
    assert_type("def foo; 1; end; foo") { int32 }
  end

  it "types a call with a float" do
    assert_type("def foo; 2.3f32; end; foo") { float32 }
  end

  it "types a call with a double" do
    assert_type("def foo; 2.3; end; foo") { float64 }
  end

  it "types a call with an argument" do
    assert_type("def foo(x); x; end; foo 1") { int32 }
  end

  it "types a call with an argument" do
    input = parse "def foo(x); x; end; foo 1; foo 2.3"
    result = infer_type input
    mod, input = result.program, result.node as Expressions

    input[1].type.should eq(mod.int32)
    input[2].type.should eq(mod.float64)
  end

  it "types a call with an argument uses a new scope" do
    assert_type("x = 2.3; def foo(x); x; end; foo 1; x") { float64 }
  end

  it "assigns def owner" do
    input = parse "struct Int; def foo; 2.5; end; end; 1.foo"
    result = infer_type input
    mod, input = result.program, result.node as Expressions
    (input.last as Call).target_def.owner.should eq(mod.int32)
  end

  it "types putchar with Char" do
    assert_type("lib LibC; fun putchar(c : Char) : Char; end; LibC.putchar 'a'") { char }
  end

  it "types getchar with Char" do
    assert_type("lib LibC; fun getchar : Char; end; LibC.getchar") { char }
  end

  it "allows recursion" do
    assert_type("def foo; foo; end; foo") { no_return }
  end

  it "allows recursion with arg" do
    assert_type("def foo(x); foo(x); end; foo 1") { no_return }
  end

  it "types simple recursion" do
    assert_type("def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)") { int32 }
  end

  it "types simple recursion 2" do
    assert_type("def foo(x); if x > 0; 1 + foo(x - 1); else; 1; end; end; foo(5)") { int32 }
  end

  it "types mutual recursion" do
    assert_type("def foo(x); if 1 == 1; bar(x); else; 1; end; end; def bar(x); foo(x); end; foo(5)") { int32 }
  end

  it "types empty body def" do
    assert_type("def foo; end; foo") { |mod| mod.nil }
  end

  it "types mutual infinite recursion" do
    assert_type("def foo; bar; end; def bar; foo; end; foo") { no_return }
  end

  it "types call with union argument" do
    assert_type("def foo(x); x; end; a = 1 || 1.1; foo(a)") { union_of(int32, float64) }
  end

  it "defines class method" do
    assert_type("def Int.foo; 2.5; end; Int.foo") { float64 }
  end

  it "defines class method with self" do
    assert_type("struct Int; def self.foo; 2.5; end; end; Int.foo") { float64 }
  end

  it "calls with default argument" do
    assert_type("def foo(x = 1); x; end; foo") { int32 }
  end

  it "do not use body for the def type" do
    input = parse "def foo; if 1 == 2; return 0; end; end; foo"
    result = infer_type input
    mod, input = result.program, result.node as Expressions

    call = input.last as Call
    call.type.should eq(mod.union_of(mod.int32, mod.nil))
    call.target_def.body.type.should eq(mod.nil)
  end

  it "reports undefined method" do
    assert_error "foo()",
      "undefined method 'foo'"
  end

  it "reports no overload matches" do
    assert_error "
      def foo(x : Int)
      end

      foo 1 || 1.5
      ",
      "no overload matches"
  end

  it "reports no overload matches 2" do
    assert_error "
      def foo(x : Int, y : Int)
      end

      def foo(x : Int, y : Double)
      end

      foo(1 || 'a', 1 || 1.5)
      ",
      "no overload matches"
  end

  it "reports no block given" do
    assert_error "
      def foo
        yield
      end

      foo
      ",
      "'foo' is expected to be invoked with a block, but no block was given"
  end

  it "reports block given" do
    assert_error "
      def foo
      end

      foo {}
      ",
      "'foo' is not expected to be invoked with a block, but a block was given"
  end

  it "errors when calling two functions with nil type" do
    assert_error "
      def bar
      end

      def foo
      end

      foo.bar
      ",
      "undefined method"
  end

  it "types call with global scope" do
    assert_type("
      def bar
        1
      end

      class Foo
        def foo
          ::bar
        end

        def bar
          'a'
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "lookups methods in super modules" do
    assert_type("
      require \"prelude\"

      module MatchesLookup
        def lookup_matches(x = 1)
          1
        end
      end

      module DefContainer
        include MatchesLookup
      end

      abstract class Type
      end

      abstract class ContainedType < Type
      end

      abstract class ModuleType < ContainedType
        include DefContainer
      end

      class NonGenericModuleType < ModuleType
      end

      class GenericModuleType < ModuleType
      end

      b = [] of Type
      b.push NonGenericModuleType.new
      b.push GenericModuleType.new
      b[0].lookup_matches
      ") { int32 }
  end

  it "fixes bug #165" do
    assert_error %(
      abstract class Node
      end

      def foo(nodes : Pointer(Node))
        foo nodes.value
      end

      a = Pointer(Node).new(0_u64)
      foo a
      ), "no overload matches"
  end

  it "says can only defined def on types and self" do
    assert_error %(
      class Foo
      end

      foo = Foo.new
      def foo.bar
      end
      ),
      "def receiver can only be a Type or self"
  end
end
