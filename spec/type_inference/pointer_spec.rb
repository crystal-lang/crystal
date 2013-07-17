require 'spec_helper'

describe 'Type inference: pointer' do
  it "types int pointer" do
    assert_type('a = 1; a.ptr') { pointer_of(int32) }
  end

  it "types pointer value" do
    assert_type('a = 1; b = a.ptr; b.value') { int32 }
  end

  it "types pointer add" do
    assert_type('a = 1; a.ptr + 1') { pointer_of(int32) }
  end

  it "types Pointer.malloc" do
    assert_type('p = Pointer(Int32).malloc(10); p.value = 1; p') { pointer_of(int32) }
  end

  it "types Pointer.null" do
    assert_type("Pointer(Int32).null") { pointer_of(int32) }
  end

  it "types realloc" do
    assert_type('p = Pointer(Int32).malloc(10); p.value = 1; x = p.realloc(20); x') { pointer_of(int32) }
  end

  it "type pointer casting" do
    assert_type('a = 1; a.ptr.as(Char)') { pointer_of(char) }
  end

  it "type pointer casting of object type" do
    assert_type('a = 1; a.ptr.as(String)') { string }
  end

  it "pointer malloc creates new type" do
    assert_type('p = Pointer(Int32).malloc(1); p.value = 1; p2 = Pointer(Float64).malloc(1); p2.value = 1.5; p2.value') { float64 }
  end

  it "allows using pointer with subclass" do
    assert_type(%q(
      a = Pointer(Object).malloc(1)
      a.value = 1
      a.value
    )) { union_of(object, int32) }
  end

  it "reports can only get pointer of variable" do
    assert_syntax_error "a.ptr",
      "can only get 'ptr' of variable or instance variable"
  end

  it "reports wrong number of arguments for ptr" do
    assert_syntax_error "a = 1; a.ptr 1",
      "wrong number of arguments for 'ptr' (1 for 0)"
  end

  it "reports ptr can't receive a block" do
    assert_syntax_error "a = 1; a.ptr {}",
      "'ptr' can't receive a block"
  end

  it "reports undefined method new" do
    assert_error "Pointer.new",
      "undefined method 'new' for Pointer(T):Class"
  end

  it "can't do Pointer.malloc without type var" do
    assert_error %(
      Pointer.malloc(1)
    ), "can't malloc pointer without type, use Pointer(Type).malloc(size)"
  end
end
