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
    nodes = parse "C.putchar 1"

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
    }.should raise_error(Crystal::Exception, regex("uninitialized constant Bar"))
  end

  it "reports superclass mismatch" do
    nodes = parse "class Foo; end; class Bar; end; class Foo < Bar; end"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("superclass mismatch for class Foo (Bar for Object)"))
  end

  it "reports Array#[]= argument must be an Int" do
    nodes = parse "[1][1.0] = 1"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("index must be Int, not Float"))
  end

  it "reports Array#[] argument must be an Int" do
    nodes = parse "[1][1.0]"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("index must be Int, not Float"))
  end

  it "reports Array::new argument must be an Int" do
    nodes = parse "Array.new 1.3, Object.new"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("size must be Int, not Float"))
  end

  it "reports can't use instance variables inside module" do
    nodes = parse "def foo; @a = 1; end; foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't use instance variables inside a module"))
  end

  it "reports can't use instance variables inside a Value" do
    nodes = parse "class Int; def foo; @a = 1; end; end; 2.foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't use instance variables inside Int"))
  end

  it "reports error when changing var type and something breaks" do
    nodes = parse "class Foo; #{rw :value}; end; f = Foo.new; f.value = 1; f.value + 1; f.value = 'a'"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("undefined method '+' for Char"))
  end

  it "reports error when changing instance var type and something breaks" do
    nodes = parse %Q(
      class Foo
        #{rw :value}
      end

      def foo(x)
        x.value = 'a'
        C.putchar x.value
      end

      f = Foo.new
      foo(f)

      f.value = 1
      )
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't call putchar with types [Int]"))
  end
end
