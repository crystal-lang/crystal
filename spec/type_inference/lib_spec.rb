require 'spec_helper'

describe 'Type inference: lib' do
  it "types a varargs external" do
    assert_type("lib Foo; fun bar(x : Int, ...) : Int; end; Foo.bar(1, 1.5, 'a')") { int }
  end

  it "reports can't call external with args" do
    assert_error "lib Foo; fun foo(x : Char); end; Foo.foo 1",
      "argument #1 to Foo.foo must be Char, not Int"
  end

  it "reports error when changing var type and something breaks" do
    assert_error "class Foo; def initialize; @value = 1; end; #{rw :value}; end; f = Foo.new; f.value + 1; f.value = 'a'",
      "undefined method '+' for Char"
  end

  it "reports must be called with out" do
    assert_error "lib Foo; fun x(c : out Int); end; a = 1; Foo.x(a)",
      "argument #1 to Foo.x must be passed as 'out'"
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
end
