require 'spec_helper'

describe 'Type inference: def' do
  it "expands a def with default arguments" do
    a_def = parse "def foo(x, y = 1, z = 2); x + y + z; end"
    expanded = a_def.expand_default_arguments

    expanded1 = parse "def foo(x, y, z); x + y + z; end"
    expanded2 = parse "def foo(x, y); foo(x, y, 2); end"
    expanded3 = parse "def foo(x); foo(x, 1); end"

    expanded.should eq([expanded1, expanded2, expanded3])
  end

  it "types a call with an int" do
    assert_type('def foo; 1; end; foo') { int32 }
  end

  it "types a call with a float" do
    assert_type('def foo; 2.3f32; end; foo') { float32 }
  end

  it "types a call with a double" do
    assert_type('def foo; 2.3; end; foo') { float64 }
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1'
    mod, input = infer_type input
    input.last.type.should eq(mod.int32)
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1; foo 2.3'
    mod, input = infer_type input
    input[1].type.should eq(mod.int32)
    input[2].type.should eq(mod.float64)
  end

  it "types a call with an argument uses a new scope" do
    assert_type('x = 2.3; def foo(x); x; end; foo 1; x') { float64 }
  end

  it "assigns def owner" do
    input = parse 'class Int; def foo; 2.5; end; end; 1.foo'
    mod, input = infer_type input
    input.last.target_def.owner.should eq(mod.int32)
  end

  it "types putchar with Char" do
    assert_type(%q(require "io"; C.putchar 'a')) { char }
  end

  it "types getchar with Char" do
    assert_type(%q(require "io"; C.getchar)) { char }
  end

  it "allows recursion" do
    input = parse "def foo; foo; end; foo"
    infer_type input
  end

  it "allows recursion with arg" do
    input = parse "def foo(x); foo(x); end; foo 1"
    infer_type input
  end

  it "types simple recursion" do
    assert_type('def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)') { int32 }
  end

  it "types recursion" do
    input = parse 'def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)'
    mod, input = infer_type input
    input.last.type.should eq(mod.int32)
    input.last.target_def.body.then.type.should eq(mod.int32)
  end

  it "types recursion 2" do
    input = parse 'def foo(x); if x > 0; 1 + foo(x - 1); else; 1; end; end; foo(5)'
    mod, input = infer_type input
    input.last.type.should eq(mod.int32)
    input.last.target_def.body.then.type.should eq(mod.int32)
  end

  it "types mutual recursion" do
    input = parse 'def foo(x); if true; bar(x); else; 1; end; end; def bar(x); foo(x); end; foo(5)'
    mod, input = infer_type input
    input.last.type.should eq(mod.int32)
    input.last.target_def.body.then.type.should eq(mod.int32)
  end

  it "types empty body def" do
    assert_type('def foo; end; foo') { self.nil }
  end

  it "types infinite recursion" do
    assert_type('def foo; foo; end; foo') { self.nil }
  end

  it "types mutual infinite recursion" do
    assert_type('def foo; bar; end; def bar; foo; end; foo') { self.nil }
  end

  it "types call with union argument" do
    assert_type('def foo(x); x; end; a = 1 || 1.1; foo(a)') { union_of(int32, float64) }
  end

  it "defines class method" do
    assert_type("def Int.foo; 2.5; end; Int.foo") { float64 }
  end

  it "defines class method with self" do
    assert_type("class Int; def self.foo; 2.5; end; end; Int.foo") { float64 }
  end

  it "calls with default argument" do
    assert_type("def foo(x = 1); x; end; foo") { int32 }
  end

  it "do not use body for the def type" do
    input = parse 'def foo; if false; return 0; end; end; foo'
    mod, input = infer_type input
    input.last.type.should eq(mod.union_of(mod.int32, mod.nil))
    input.last.target_def.body.type.should eq(mod.nil)
  end

  it "reports undefined method" do
    assert_error "foo()",
      "undefined method 'foo'"
  end

  it "reports no overload matches" do
    assert_error %(
      def foo(x : Int)
      end

      foo 1 || 1.5
      ),
      "no overload matches"
  end

  it "reports no overload matches 2" do
    assert_error %(
      def foo(x : Int, y : Int)
      end

      def foo(x : Int, y : Double)
      end

      foo(1 || 'a', 1 || 1.5)
      ),
      "no overload matches"
  end

  it "reports no block given" do
    assert_error %(
      def foo
        yield
      end

      foo
      ),
      "'foo' is expected to be invoked with a block, but no block was given"
  end

  it "reports block given" do
    assert_error %(
      def foo
      end

      foo {}
      ),
      "'foo' is not expected to be invoked with a block, but a block was given"
  end
end
