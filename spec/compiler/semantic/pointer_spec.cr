require "../../spec_helper"

describe "Semantic: pointer" do
  it "types int pointer" do
    assert_type("a = 1; pointerof(a)") { pointer_of(int32) }
  end

  it "types pointer value" do
    assert_type("a = 1; b = pointerof(a); b.value") { int32 }
  end

  it "types pointer add" do
    assert_type("a = 1; pointerof(a) + 1_i64") { pointer_of(int32) }
  end

  it "types pointer diff" do
    assert_type("a = 1; b = 2; pointerof(a) - pointerof(b)") { int64 }
  end

  it "types Pointer.malloc" do
    assert_type("p = Pointer(Int32).malloc(10_u64); p.value = 1; p") { pointer_of(int32) }
  end

  it "types realloc" do
    assert_type("p = Pointer(Int32).malloc(10_u64); p.value = 1; x = p.realloc(20_u64); x") { pointer_of(int32) }
  end

  it "type pointer casting" do
    assert_type("a = 1; pointerof(a).as(Char*)") { pointer_of(char) }
  end

  it "type pointer casting of object type" do
    assert_type("a = 1; pointerof(a).as(String)") { string }
  end

  it "pointer malloc creates new type" do
    assert_type("p = Pointer(Int32).malloc(1_u64); p.value = 1; p2 = Pointer(Float64).malloc(1_u64); p2.value = 1.5; p2.value") { float64 }
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
    ", "can't malloc pointer without type, use Pointer(Type).malloc(size)"
  end

  it "create pointer by address" do
    assert_type("Pointer(Int32).new(123_u64)") { pointer_of(int32) }
  end

  it "types nil or pointer type" do
    result = assert_type("1 == 1 ? nil : Pointer(Int32).new(0_u64)") { nilable pointer_of(int32) }
    result.node.type.should be_a(NilablePointerType)
  end

  it "types nil or pointer type with typedef" do
    result = assert_type(%(
      lib LibC
        type T = Void*
        fun foo : T?
      end
      LibC.foo
      )) { nilable types["LibC"].types["T"] }
    result.node.type.should be_a(NilablePointerType)
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
      )) { int32 }
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

  it "errors if using nil? on pointer type" do
    assert_error %(
      a = 1
      pointerof(a).nil?
      ),
      "use `null?`"
  end

  it "errors if using nil? on union including pointer type" do
    assert_error %(
      a = 1
      (1 || pointerof(a)).nil?
      ),
      "use `null?`"
  end

  it "can assign nil to void pointer" do
    assert_type(%(
      ptr = Pointer(Void).malloc(1_u64)
      ptr.value = ptr.value
      )) { nil_type }
  end

  it "can pass any pointer to something expecting void* in lib call" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Void*) : Float64
      end

      LibFoo.foo(Pointer(Int32).malloc(1_u64))
      )) { float64 }
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
      )) { float64 }
  end

  it "errors if doing Pointer.allocate" do
    assert_error %(
      Pointer(Int32).allocate
      ),
      "can't create instance of a pointer type"
  end
end
