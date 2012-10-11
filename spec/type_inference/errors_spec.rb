require 'spec_helper'

describe 'Type inference: errors' do
  it "reports undefined local variable or method" do
    nodes = parse %(
      def foo
        a = something
      end

      def bar
        foo
      end

      bar).strip
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("undefined local variable or method 'something'"))
  end

  it "reports undefined method" do
    nodes = parse "foo()"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, /undefined method 'foo'/)
  end

  it "reports wrong number of arguments" do
    nodes = parse "def foo(x); x; end; foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("wrong number of arguments for 'foo' (0 for 1)"))
  end

  it "reports undefined method when method inside a class" do
    nodes = parse "class Int; def foo; 1; end; end; foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("undefined local variable or method 'foo'"))
  end

  it "reports undefined instance method" do
    nodes = parse "1.foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("undefined method 'foo' for Int"))
  end

  it "reports can't call primitive with args" do
    nodes = parse "1 + 'a'"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't call Int#+ with types [Char]"))
  end

  it "reports can't call external with args" do
    nodes = parse "putchar 1"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't call putchar with types [Int]"))
  end

  it "reports uninitialized constant" do
    nodes = parse "Foo.new"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("uninitialized constant Foo"))
  end

  it "reports unknown class when extending" do
    nodes = parse "class Foo < Bar; end"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("unknown class Bar"))
  end
end
