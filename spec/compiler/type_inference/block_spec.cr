#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Block inference" do
  it "infer type of empty block body" do
    assert_type("
      def foo; yield; end

      foo do
      end
    ") { |mod| mod.nil }
  end

  it "infer type of block body" do
    input = parse("
      def foo; yield; end

      foo do
        x = 1
      end
    ") as Expressions
    result = infer_type input
    (input.last as Call).block.not_nil!.body.type.should eq(result.program.int32)
  end

  it "infer type of block argument" do
    input = parse("
      def foo
        yield 1
      end

      foo do |x|
        1
      end
    ") as Expressions
    result = infer_type input
    mod = result.program
    (input.last as Call).block.not_nil!.args[0].type.should eq(mod.int32)
  end

  it "infer type of local variable" do
    assert_type("
      def foo
        yield 1
      end

      y = 'a'
      foo do |x|
        y = x
      end
      y
    ") { union_of(char, int32) }
  end

  it "infer type of yield" do
    assert_type("
      def foo
        yield
      end

      foo do
        1
      end
    ") { int32 }
  end

  it "infer type with union" do
    assert_type("
      require \"prelude\"
      a = [1] || [1.1]
      a.each { |x| x }
    ") { union_of(array_of(int32), array_of(float64)) }
  end

  it "break from block without value" do
    assert_type("
      def foo; yield; end

      foo do
        break
      end
    ") { |mod| mod.nil }
  end

  it "break without value has nil type" do
    assert_type("
      def foo; yield; 1; end
      foo do
        break if false
      end
    ") { |mod| union_of(mod.nil, int32) }
  end

  it "infers type of block before call" do
    result = assert_type("
      struct Int32
        def foo
          10.5
        end
      end

      class Foo(T)
        def initialize(x : T)
          @x = x
        end
      end

      def bar(&block : Int32 -> U)
        Foo(U).new(yield 1)
      end

      bar { |x| x.foo }
      ") do
      (types["Foo"] as GenericClassType).instantiate([float64] of TypeVar)
    end
    mod = result.program
    type = result.node.type as GenericClassInstanceType
    type.type_vars["T"].type.should eq(mod.float64)
    type.instance_vars["@x"].type.should eq(mod.float64)
  end

  it "infers type of block before call taking other args free vars into account" do
    assert_type("
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
      ") do
      (types["Foo"] as GenericClassType).instantiate([float64] of TypeVar)
    end
  end

  it "reports error if yields a type that's not that one in the block specification" do
    assert_error "
      def foo(&block: Int32 -> )
        yield 10.5
      end

      foo {}
      ",
      "argument #1 of yield expected to be Int32, not Float64"
  end

  it "reports error if yields a type that's not that one in the block specification and type changes" do
    assert_error "
      $global = 1

      def foo(&block: Int32 -> )
        yield $global
        $global = 10.5
      end

      foo {}
      ",
      "type must be Int32, not"
  end

  it "doesn't report error if yields nil but nothing is yielded" do
    assert_type("
      def foo(&block: Int32, Nil -> )
        yield 1
      end

      foo { |x| x }
      ") { int32 }
  end

  it "reports error if missing arguments to yield" do
    assert_error "
      def foo(&block: Int32, Int32 -> )
        yield 1
      end

      foo { |x| x }
      ",
      "missing argument #2 of yield with type Int32"
  end

  it "reports error if block didn't return expected type" do
    assert_error "
      def foo(&block: Int32 -> Float64)
        yield 1
      end

      foo { 'a' }
      ",
      "expected block to return Float64, not Char"
  end

  it "reports error if block changes type" do
    assert_error "
      def foo(&block: Int32 -> Float64)
        yield 1
      end

      $global = 10.5
      foo { $global }
      $global = 'a'
      ",
      "type must be Float64"
  end

  it "matches block arg return type" do
    assert_type("
      class Foo(T)
      end

      def foo(&block: Int32 -> Foo(T))
        yield 1
        Foo(T).new
      end

      foo { Foo(Float64).new }
      ") do
      (types["Foo"] as GenericClassType).instantiate([float64] of TypeVar)
    end
  end

  it "infers type of block with generic type" do
    assert_type("
      class Foo(T)
      end

      def foo(&block: Foo(Int32) -> )
        yield Foo(Int32).new
      end

      foo do |x|
        10.5
      end
      ") { float64 }
  end

  it "infer type with self block arg" do
    assert_type("
      class Foo
        def foo(&block : self -> )
          yield self
        end
      end

      f = Foo.new
      a = nil
      f.foo do |x|
        a = x
      end
      a
      ") { |mod| union_of(types["Foo"], mod.nil) }
  end

  it "error with self input type doesn't match" do
    assert_error "
      class Foo
        def foo(&block : self -> )
          yield 1
        end
      end

      f = Foo.new
      f.foo {}
      ",
      "argument #1 of yield expected to be Foo, not Int32"
  end

  it "error with self output type doesn't match" do
    assert_error "
      class Foo
        def foo(&block : Int32 -> self )
          yield 1
        end
      end

      f = Foo.new
      f.foo { 1 }
      ",
      "expected block to return Foo, not Int32"
  end

  assert_syntax_error "a = 1; foo { |a| }",
                      "block argument 'a' shadows local variable 'a'"

  it "errors when using local varaible with block argument name" do
    assert_error "def foo; yield; end; foo { |a| }; a",
      "undefined local variable or method 'a'"
  end

  it "types empty block" do
    assert_type("
      def foo
        ret = yield
        ret
      end

      foo { }
    ") { |mod| mod.nil }
  end

  it "preserves type filters in block" do
    assert_type("
      class Foo
        def bar
          'a'
        end
      end

      def foo
        yield 1
      end

      a = Foo.new || nil
      if a
        foo do |x|
          a.bar
        end
      else
        'b'
      end
      ") { char }
  end

  it "checks block type with virtual type" do
    assert_type("
      require \"prelude\"

      class A
      end

      class B < A
      end

      a = [] of A
      a << B.new

      a.map { |x| x.to_s }

      1
      ") { int32 }
  end

  it "maps block of union types to union types" do
    assert_type("
      require \"prelude\"

      class Foo1
      end

      class Bar1 < Foo1
      end

      class Foo2
      end

      class Bar2 < Foo2
      end

      a = [Foo1.new, Foo2.new, Bar1.new, Bar2.new]
      a.map { |x| x }
      ") { array_of(union_of(types["Foo1"].virtual_type, types["Foo2"].virtual_type)) }
  end

  it "does next from block without value" do
    assert_type("
      def foo; yield; end

      foo do
        next
      end
    ") { |mod| mod.nil }
  end

  it "does next from block with value" do
    assert_type("
      def foo; yield; end

      foo do
        next 1
      end
    ") { int32 }
  end

  it "does next from block with value 2" do
    assert_type("
      def foo; yield; end

      foo do
        if 1 == 1
          next 1
        end
        false
      end
    ") { union_of(int32, bool) }
  end

  it "ignores block parameter if not used" do
    assert_type(%(
      def foo(&block)
        yield 1
      end

      foo do |x|
        x + 1
      end
      )) { int32 }
  end

  it "allows yielding multiple types when a union is expected" do
    assert_type(%(
      require "prelude"

      class Foo
        include Enumerable(Int32 | Float64)

        def each
          yield 1
          yield 1.5
        end
      end

      foo = Foo.new
      foo.map &.to_f
      )) { array_of(float64) }
  end

  it "allows initialize with yield (#224)" do
    assert_type(%(
      class Foo
        def initialize
          @x = yield 1
        end

        def x
          @x
        end
      end

      foo = Foo.new do |a|
        a + 1
      end
      foo.x
      )) { int32 }
  end

  it "passes #233: block with initialize with default args" do
    assert_type(%(
      class Foo
        def initialize(x = nil)
          yield
        end
      end

      Foo.new {}
      )) { types["Foo"] }
  end

  it "errors if declares def inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        def bar
        end
      end
      ),
      "can't declare def inside block"
  end

  it "errors if declares macro inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        macro bar
        end
      end
      ),
      "can't declare macro inside block"
  end

  it "errors if declares fun inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        fun bar : Int32
        end
      end
      ),
      "can't declare fun inside block"
  end

  it "errors if declares class inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        class Foo
        end
      end
      ),
      "can't declare class inside block"
  end

  it "errors if declares module inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        module Foo
        end
      end
      ),
      "can't declare module inside block"
  end

  it "errors if declares lib inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        lib Foo
        end
      end
      ),
      "can't declare lib inside block"
  end

  it "errors if declares alias inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        alias A = Int32
      end
      ),
      "can't declare alias inside block"
  end

  it "errors if declares include inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        include Int32
      end
      ),
      "can't include inside block"
  end

  it "errors if declares extend inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        extend Int32
      end
      ),
      "can't extend inside block"
  end

  it "errors if declares enum inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        enum Foo
          A
        end
      end
      ),
      "can't declare enum inside block"
  end
end
