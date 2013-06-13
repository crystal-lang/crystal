require 'spec_helper'

describe 'Type inference: lib' do
  it "types a varargs external" do
    assert_type("lib Foo; fun bar(x : Int32, ...) : Int32; end; Foo.bar(1, 1.5, 'a')") { int32 }
  end

  it "reports can't call external with args" do
    assert_error "lib Foo; fun foo(x : Char); end; Foo.foo 1",
      "argument #1 to Foo.foo must be Char, not Int32"
  end

  it "reports error when changing var type and something breaks" do
    assert_error "class Foo; def initialize; @value = 1; end; #{rw :value}; end; f = Foo.new; f.value + 1; f.value = 'a'",
      "undefined method '+' for Char"
  end

  it "reports error when changing instance var type and something breaks" do
    assert_error %Q(
      lib Lib
        fun bar(c : Char)
      end

      class Foo
        #{rw :value}
      end

      def foo(x)
        x.value = 'a'
        Lib.bar x.value
      end

      f = Foo.new
      foo(f)

      f.value = 1
      ),
      "argument #1 to Lib.bar must be Char"
  end

  it "reports error on fun argument type not primitive like" do
    assert_error "lib Foo; fun foo(x : Reference); end",
      "only primitive types and structs are allowed in lib declarations"
  end

  it "reports error on fun return type not primitive like" do
    assert_error "lib Foo; fun foo : Reference; end",
      "only primitive types and structs are allowed in lib declarations"
  end

  it "reports error on struct field type not primitive like" do
    assert_error "lib Foo; struct Foo; x : Reference; end; end",
      "only primitive types and structs are allowed in lib declarations"
  end

  it "reports error on typedef type not primitive like" do
    assert_error "lib Foo; type Foo : Reference; end",
      "only primitive types and structs are allowed in lib declarations"
  end
end
