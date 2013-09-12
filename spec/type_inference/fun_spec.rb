require 'spec_helper'

describe 'Type inference: fun' do
  it "types empty fun literal" do
    assert_type("-> {}") { fun_of(self.nil) }
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

  pending "types fun pointer to instance method" do
    assert_type(%(
      class Foo
        def coco
          1
        end
      end

      ->Foo.new.coco
    )) { fun_of(int32) }
  end

  it "types fun type spec" do
    assert_type("a = Pointer(Int32 -> Int64).malloc(1_u64)") { pointer_of(fun_of(int32, int64)) }
  end

  it "allows passing fun type if it is typedefed" do
    assert_type(%q(
      lib C
        type Callback : Int32 -> Int32
        fun foo(x : Callback) : Float64
      end

      f = ->(x : Int32) { x + 1 }
      C.foo f
      )) { float64 }
  end
end
