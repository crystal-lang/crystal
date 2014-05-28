#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: fun" do
  it "types empty fun literal" do
    assert_type("-> {}") { |mod| fun_of(mod.nil) }
  end

  it "types int fun literal" do
    assert_type("-> { 1 }") { fun_of(int32) }
  end

  it "types fun call" do
    assert_type("x = -> { 1 }; x.call()") { int32 }
  end

  it "types int -> int fun literal" do
    assert_type("->(x : Int32) { x }") { fun_of(int32, int32) }
  end

  it "types int -> int fun call" do
    assert_type("f = ->(x : Int32) { x }; f.call(1)") { int32 }
  end

  it "types fun pointer" do
    assert_type("def foo; 1; end; ->foo") { fun_of(int32) }
  end

  it "types fun pointer with types" do
    assert_type("def foo(x); x; end; ->foo(Int32)") { fun_of(int32, int32) }
  end

  it "types a fun pointer with generic types" do
    assert_type("def foo(x); end; ->foo(Pointer(Int32))") { |mod| fun_of(pointer_of(int32), mod.nil) }
  end

  it "types fun pointer to instance method" do
    assert_type("
      class Foo
        def initialize
          @x = 1
        end

        def coco
          @x
        end
      end

      foo = Foo.new
      ->foo.coco
    ") { fun_of(int32) }
  end

  it "types fun type spec" do
    assert_type("a = Pointer(Int32 -> Int64).malloc(1_u64)") { pointer_of(fun_of(int32, int64)) }
  end

  it "allows passing fun type if it is typedefed" do
    assert_type("
      lib C
        type Callback : Int32 -> Int32
        fun foo(x : Callback) : Float64
      end

      f = ->(x : Int32) { x + 1 }
      C.foo f
      ") { float64 }
  end

  it "errors when fun varaible shadows local variable" do
    assert_syntax_error "a = 1; ->(a : Foo) { }",
      "function argument 'a' shadows local variable 'a'"
  end

  it "errors when using local varaible with fun argument name" do
    assert_error "->(a : Int32) { }; a",
      "undefined local variable or method 'a'"
  end

  # it "types int -> int fun literal as a block" do
  #   assert_type("def foo(&block : Int32 ->); block; end; foo { |x| x + 2 }") { fun_of(int32, int32) }
  # end

  it "allows implicit cast of fun to return void in C function" do
    assert_type("
      lib C
        fun atexit(fun : -> ) : Int32
      end

      C.atexit ->{ 1 }
      ") { int32 }
  end

  it "passes fun pointer as block" do
    assert_type("
      def foo
        yield
      end

      f = -> { 1 }
      foo &f
      ") { int32 }
  end

  it "passes fun pointer as block with arguments" do
    assert_type("
      def foo
        yield 1
      end

      f = ->(x : Int32) { x.to_f }
      foo &f
      ") { float64 }
  end

  it "binds fun literal to arguments and body" do
    assert_type("
      $x = 1
      f = -> { $x }
      $x = 'a'
      f
    ") { fun_of(union_of(int32, char)) }
  end

  it "has fun literal as restriction and works" do
    assert_type("
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32) { x.to_f }
      ") { float64 }
  end

  it "has fun literal as restriction and works when output not specified" do
    assert_type("
      def foo(x : Int32 -> )
        x.call(1)
      end

      foo ->(x : Int32) { x.to_f }
      ") { float64 }
  end

  it "has fun literal as restriction and errors if output is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32) { x }
      ",
      "no overload matches"
  end

  it "has fun literal as restriction and errors if input is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int64) { x.to_f }
      ",
      "no overload matches"
  end

  it "has fun literal as restriction and errors if lengths is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32, y : Int32) { x.to_f }
      ",
      "no overload matches"
  end

  it "allows passing nil as fun callback" do
    assert_type("
      lib C
        type Cb : Int32 ->
        fun bla(Cb) : Int32
      end

      C.bla(nil)
      ") { int32 }
  end

  it "allows casting a fun type to one accepting more arguments" do
    assert_type("
      f = ->(x : Int32) { x.to_f }
      f as Int32, Int32 -> Float64
      ") { fun_of [int32, int32, float64] }
  end

  it "allows casting a fun type to one with void argument" do
    assert_type("
      f = ->(x : Int32) { x.to_f }
      f as Int32 -> Void
      ") { fun_of [int32, void] }
  end

  it "disallows casting a fun type to one accepting less arguments" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f as -> Float64
      ",
      "can't cast Int32 -> Float64 to  -> Float64"
  end

  it "disallows casting a fun type to one accepting same length argument but different output" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f as Int32 -> Int32
      ",
      "can't cast Int32 -> Float64 to Int32 -> Int32"
  end

  it "disallows casting a fun type to one accepting same length argument but different input" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f as Float64 -> Float64
      ",
      "can't cast Int32 -> Float64 to Float64 -> Float64"
  end

  it "inherits Reference" do
    assert_type("->{}.object_id") { uint64 }
  end

  it "types fun literal hard type inference (1)" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      ->(f : Foo) do
        {Foo.new(f.x), 0}
      end
      )) { fun_of(types["Foo"], tuple_of([no_return, int32])) }
  end
end
