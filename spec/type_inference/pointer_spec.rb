require 'spec_helper'

describe 'Type inference: pointer' do
  it "types int pointer" do
    assert_type('a = 1; a.ptr') { pointer_of(int) }
  end

  it "types pointer value" do
    assert_type('a = 1; b = a.ptr; b.value') { int }
  end

  it "types pointer add" do
    assert_type('a = 1; a.ptr + 1') { pointer_of(int) }
  end

  it "types Pointer.malloc" do
    assert_type('p = Pointer(Int).malloc(10); p.value = 1; p') { pointer_of(int) }
  end

  it "types realloc" do
    assert_type('p = Pointer(Int).malloc(10); p.value = 1; x = p.realloc(20); x') { pointer_of(int) }
  end

  it "type pointer casting" do
    assert_type('a = 1; a.ptr.as(Char)') { pointer_of(char) }
  end

  it "type pointer casting of object type" do
    assert_type('a = 1; a.ptr.as(String)') { string }
  end

  it "pointer malloc creates new type" do
    assert_type('p = Pointer(Int).malloc(1); p.value = 1; p2 = Pointer(Double).malloc(1); p2.value = 1.5; p2.value') { double }
  end

  it "allows using pointer with subclass" do
    assert_type(%q(
      a = Pointer(Object).malloc(1)
      a.value = 1
      a.value
    )) { union_of(object, int) }
  end
end