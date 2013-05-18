require 'spec_helper'

describe 'Block inference' do
  it "infer type of empty block body" do
    assert_type(%q(
      def foo; yield; end

      foo do
      end
    )) { self.nil }
  end

  it "infer type of yield with empty block" do
    assert_type(%q(
      def foo
        yield
      end

      foo do
      end
    )) { self.nil }
  end

  it "infer type of block body" do
    input = parse %q(
      def foo; yield; end

      foo do
        x = 1
      end
    )
    mod = infer_type input
    input.last.block.body.target.type.should eq(mod.int)
  end

  it "infer type of block argument" do
    input = parse %q(
      def foo
        yield 1
      end

      foo do |x|
        1
      end
    )
    mod = infer_type input
    input.last.block.args[0].type.should eq(mod.int)
  end

  it "infer type of local variable" do
    input = parse %q(
      def foo
        yield 1
      end

      y = 'a'
      foo do |x|
        y = x
      end
      y
    )
    mod = infer_type input
    input.last.type.should eq(UnionType.new(mod.char, mod.int))
  end

  it "infer type of yield" do
    input = parse %q(
      def foo
        yield
      end

      foo do
        1
      end
    )
    mod = infer_type input
    input.last.type.should eq(mod.int)
  end

  it "infer type with union" do
    assert_type(%q(
      require "int"
      require "pointer"
      require "array"
      a = [1]
      a = [1.1]
      a.each { |x| x }
    )) { union_of(array_of(int), array_of(double)) }
  end

  it "break from block without value" do
    assert_type(%q(
      def foo; yield; end

      foo do
        break
      end
    )) { self.nil }
  end

  it "break without value has nil type" do
    assert_type(%q(
      def foo; yield; 1; end
      foo do
        break if false
      end
    )) { union_of(self.nil, int) }
  end

  it "infers type of block before call" do
    assert_type(%q(
      class Int
        def foo
          10.5
        end
      end

      class Foo(T)
        def initialize(x : T)
          @x = x
        end
      end

      def bar(&block : Int -> U)
        Foo(U).new(yield 1)
      end

      bar { |x| x.foo }
      )) { "Foo".generic(T: double).with_vars(x: double) }
  end

  it "infers type of block before call taking other args free vars into account" do
    assert_type(%q(
      class Foo(X)
        def initialize(x : X)
          @x = x
        end
      end

      def foo(x : U, &block: U -> T)
        Foo(T).new(yield x)
      end

      a = foo(1) do |x|
        10.5
      end
      )) { "Foo".generic(X: double).with_vars(x: double) }
  end

  it "reports error if yields a type that's not that one in the block specification" do
    assert_error %q(
      def foo(&block: Int -> )
        yield 10.5
      end

      foo {}
      ),
      "argument #1 of yield expected to be Int, not Double"
  end

  it "reports error if yields a type that's not that one in the block specification and type changes" do
    assert_error %q(
      def foo(&block: Int -> )
        a = 1
        yield a
        a = 10.5
      end

      foo {}
      ),
      "type must be Int, not"
  end

  it "doesn't report error if yields nil but nothing is yielded" do
    assert_type(%q(
      def foo(&block: Int, Nil -> )
        yield 1
      end

      foo { |x| x }
      )) { int }
  end

  it "reports error if missing arguments to yield" do
    assert_error %q(
      def foo(&block: Int, Int -> )
        yield 1
      end

      foo { |x| x }
      ),
      "missing argument #2 of yield with type Int"
  end

  it "reports error if block didn't return expected type" do
    assert_error %q(
      def foo(&block: Int -> Double)
        yield 1
      end

      foo { 'a' }
      ),
      "block expected to return Double, not Char"
  end

  it "reports error if block changes type" do
    assert_error %q(
      def foo(&block: Int -> Double)
        yield 1
      end

      a = 10.5
      foo { a }
      a = 1
      ),
      "type must be Double"
  end

  it "matches block arg return type" do
    assert_type(%q(
      class Foo(T)
      end

      def foo(&block: Int -> Foo(T))
        yield 1
        Foo(T).new
      end

      foo { Foo(Double).new }
      )) { "Foo".generic(T: double) }
  end

  it "infers type of block with generic type" do
    assert_type(%q(
      class Foo(T)
      end

      def foo(&block: Foo(Int) -> )
        yield Foo(Int).new
      end

      foo do |x|
        10.5
      end
      )) { double }
  end
end
