require 'spec_helper'

describe 'Type inference: pointer' do
  it "types int pointer" do
    assert_type('a = 1; a.ptr') { PointerType.of(int) }
  end

  it "types pointer value" do
    assert_type('a = 1; b = a.ptr; b.value') { int }
  end

  it "types pointer set value" do
    assert_type(%q(
      class Foo
        def foo
          p = @value.ptr
          p.value = 1
        end
        def value
          @value
        end
      end

      f = Foo.new
      f.foo
      f.value)) { int }
  end

  it "types pointer add" do
    assert_type('a = 1; a.ptr + 1') { PointerType.of(int) }
  end

  it "types Pointer.malloc" do
    assert_type('p = Pointer.malloc(10); p.value = 1; p') { PointerType.of(int) }
  end

  it "types Pointer.malloc with value" do
    assert_type('p = Pointer.malloc(10, 1); p') { PointerType.of(int) }
  end

  it "types realloc" do
    assert_type('p = Pointer.malloc(10); p.value = 1; x = p.realloc(20); x') { PointerType.of(int) }
  end

  it "type pointer casting" do
    assert_type('a = 1; a.ptr.as(Char)') { PointerType.of(char) }
  end

  it "type pointer casting of object type" do
    assert_type('a = 1; a.ptr.as(String)') { string }
  end

  it "pointer malloc creates new type" do
    assert_type('p = Pointer.malloc(1); p.value = 1; p2 = Pointer.malloc(1); p2.value = 1.5; p2.value') { float }
  end
end