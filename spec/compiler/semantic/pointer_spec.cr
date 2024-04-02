require "../../spec_helper"

describe "Semantic: pointer" do
  it "types int pointer" do
    assert_type("a = 1; pointerof(a)") { pointer_of(int32) }
  end

  it "types pointer value" do
    assert_type("a = 1; b = pointerof(a); b.value", inject_primitives: true) { int32 }
  end

  it "types pointer add" do
    assert_type("a = 1; pointerof(a) + 1_i64", inject_primitives: true) { pointer_of(int32) }
  end

  it "types pointer diff" do
    assert_type("a = 1; b = 2; pointerof(a) - pointerof(b)", inject_primitives: true) { int64 }
  end

  it "types Pointer.malloc" do
    assert_type("p = Pointer(Int32).malloc(10_u64); p.value = 1; p", inject_primitives: true) { pointer_of(int32) }
  end

  it "types realloc" do
    assert_type("p = Pointer(Int32).malloc(10_u64); p.value = 1; x = p.realloc(20_u64); x", inject_primitives: true) { pointer_of(int32) }
  end

  it "type pointer casting" do
    assert_type("a = 1; pointerof(a).as(Char*)") { pointer_of(char) }
  end

  it "type pointer casting of object type" do
    assert_type("a = 1; pointerof(a).as(String)") { string }
  end

  it "pointer malloc creates new type" do
    assert_type("p = Pointer(Int32).malloc(1_u64); p.value = 1; p2 = Pointer(Float64).malloc(1_u64); p2.value = 1.5; p2.value", inject_primitives: true) { float64 }
  end

  pending "allows using pointer with subclass" do
    assert_type("
      a = Pointer(Object).malloc(1_u64)
      a.value = 1
      a.value
    ") { union_of(object.virtual_type, int32) }
  end

  it "can't do Pointer.malloc without type var" do
    assert_error "
      Pointer.malloc(1_u64)
    ", "can't malloc pointer without type, use Pointer(Type).malloc(size)", inject_primitives: true
  end

  it "create pointer by address" do
    assert_type("Pointer(Int32).new(123_u64)", inject_primitives: true) { pointer_of(int32) }
  end

  it "types pointer of constant" do
    result = assert_type("
      FOO = 1
      pointerof(FOO)
    ") { pointer_of(int32) }
  end

  it "pointer of class raises error" do
    assert_error "pointerof(Int32)", "can't take address of Int32"
  end

  it "pointer of value error" do
    assert_error "pointerof(1)", "can't take address of 1"
  end

  it "types pointer value on typedef" do
    assert_type(%(
      lib LibC
        type Foo = Int32*
        fun foo : Foo
      end

      LibC.foo.value
      ), inject_primitives: true) { int32 }
  end

  it "detects recursive pointerof expansion (#551) (#553)" do
    assert_error %(
      x = 1
      x = pointerof(x)
      ),
      "recursive pointerof expansion"
  end

  it "detects recursive pointerof expansion (2) (#1654)" do
    assert_error %(
      x = 1
      pointer = pointerof(x)
      x = pointerof(pointer)
      ),
      "recursive pointerof expansion"
  end

  it "detects recursive pointerof expansion (3)" do
    assert_error <<-CRYSTAL, "recursive pointerof expansion"
      x = {1}
      x = pointerof(x)
      CRYSTAL
  end

  it "detects recursive pointerof expansion (4)" do
    assert_error <<-CRYSTAL, "recursive pointerof expansion"
      x = 1
      x = {pointerof(x)}
      CRYSTAL
  end

  it "doesn't crash if pointerof expansion type has generic splat parameter (#11808)" do
    assert_type(<<-CRYSTAL) { pointer_of(union_of int32, generic_class("Foo", string)) }
      class Foo(*T)
      end

      x = 1
      pointer = pointerof(x)
      x = Foo(String).new
      pointer
      CRYSTAL
  end

  it "can assign nil to void pointer" do
    assert_type(%(
      ptr = Pointer(Void).malloc(1_u64)
      ptr.value = ptr.value
      ), inject_primitives: true) { nil_type }
  end

  it "can pass any pointer to something expecting void* in lib call" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Void*) : Float64
      end

      LibFoo.foo(Pointer(Int32).malloc(1_u64))
      ), inject_primitives: true) { float64 }
  end

  it "can pass any pointer to something expecting void* in lib call, with to_unsafe" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Void*) : Float64
      end

      class Foo
        def to_unsafe
          Pointer(Int32).malloc(1_u64)
        end
      end

      LibFoo.foo(Foo.new)
      ), inject_primitives: true) { float64 }
  end

  it "errors if doing Pointer.allocate" do
    assert_error %(
      Pointer(Int32).allocate
      ),
      "can't create instance of a pointer type"
  end

  it "takes pointerof lib external var" do
    assert_type(%(
      lib LibFoo
        $extern : Int32
      end

      pointerof(LibFoo.extern)
      )) { pointer_of(int32) }
  end

  it "says undefined variable (#7556)" do
    assert_error %(
      pointerof(foo)
      ),
      "undefined local variable or method 'foo'"
  end

  it "can assign pointerof virtual type (#8216)" do
    assert_no_errors <<-CRYSTAL
      class Base
      end

      class Sub < Base
      end

      u = uninitialized Base

      x : Pointer(Base)
      x = pointerof(u)
      CRYSTAL
  end

  it "errors with non-matching generic value with value= (#10211)" do
    assert_error %(
      class Gen(T)
      end

      ptr = Pointer(Gen(Char | Int32)).malloc(1_u64)
      ptr.value = Gen(Int32).new
      ),
      "type must be Gen(Char | Int32), not Gen(Int32)", inject_primitives: true
  end

  it "errors with non-matching generic value with value=, generic type (#10211)" do
    assert_error %(
      module Moo(T)
      end

      class Foo(T)
        include Moo(T)
      end

      ptr = Pointer(Moo(Char | Int32)).malloc(1_u64)
      ptr.value = Foo(Int32).new
      ),
      "type must be Moo(Char | Int32), not Foo(Int32)", inject_primitives: true
  end

  it "errors with non-matching generic value with value=, union of generic types (#10544)" do
    assert_error %(
      class Foo(T)
      end

      class Bar1
      end

      class Bar2
      end

      ptr = Pointer(Foo(Char | Int32)).malloc(1_u64)
      ptr.value = Foo(Int32).new || Foo(Char | Int32).new
      ),
      "type must be Foo(Char | Int32), not (Foo(Char | Int32) | Foo(Int32))", inject_primitives: true
  end
end
