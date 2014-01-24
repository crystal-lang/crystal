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

  it "types int -> int fun literal as a block" do
    assert_type("def foo(&block : Int32 ->); block; end; foo { |x| x + 2 }") { fun_of(int32, int32) }
  end

  it "allows fun to return something else than void if it's not void" do
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
end
