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
    }.should raise_error(Crystal::Exception, regex("no overload matches"))
  end

  it "reports can't call external with args" do
    nodes = parse "lib Foo; fun foo(x : Char); end; Foo.foo 1"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("argument #1 to Foo.foo must be Char, not Int"))
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

  it "reports can't use instance variables inside module" do
    nodes = parse "def foo; @a = 1; end; foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't use instance variables at the top level"))
  end

  it "reports can't use instance variables inside a Value" do
    nodes = parse "class Int; def foo; @a = 1; end; end; 2.foo"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't use instance variables inside Int"))
  end

  it "reports error when changing var type and something breaks" do
    nodes = parse "class Foo; def initialize; @value = 1; end; #{rw :value}; end; f = Foo.new; f.value + 1; f.value = 'a'"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("undefined method '+' for Char"))
  end

  it "reports must be called with out" do
    nodes = parse "lib Foo; fun x(c : out Int); end; a = 1; Foo.x(a)"

    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("argument #1 to Foo.x must be passed as 'out'"))
  end

  it "reports error when changing instance var type and something breaks" do
    nodes = parse %Q(
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
      )
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("argument #1 to Lib.bar must be Char"))
  end

  it "reports can only get pointer of variable" do
    lambda {
      parse %Q(a.ptr)
    }.should raise_error(Crystal::SyntaxException, regex("can only get 'ptr' of variable or instance variable"))
  end

  it "reports wrong number of arguments for ptr" do
    lambda {
      parse %Q(a = 1; a.ptr 1)
    }.should raise_error(Crystal::SyntaxException, regex("wrong number of arguments for 'ptr' (1 for 0)"))
  end

  it "reports ptr can't receive a block" do
    lambda {
      parse %Q(a = 1; a.ptr {})
    }.should raise_error(Crystal::SyntaxException, regex("'ptr' can't receive a block"))
  end

  it "reports break cannot be used outside a while" do
    nodes = parse 'break'
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("Invalid break"))
  end

  it "reports read before assignment" do
    lambda {
      parse %Q(a += 1)
    }.should raise_error(Crystal::SyntaxException, regex("'+=' before definition of 'a'"))
  end

  it "reports no overload matches" do
    nodes = parse %(
      def foo(x : Int)
      end

      foo 1 || 1.5
      )
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("no overload matches"))
  end

  it "reports no overload matches 2" do
    nodes = parse %(
      def foo(x : Int, y : Int)
      end

      def foo(x : Int, y : Double)
      end

      foo(1 || 'a', 1 || 1.5)
      )
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("no overload matches"))
  end

  it "reports no matches for hierarchy type" do
    nodes = parse %(
      class Foo
      end

      class Bar < Foo
        def foo
        end
      end

      x = Foo.new || Bar.new
      x.foo
    )
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("undefined method 'foo'"))
  end

  it "can't do Pointer.malloc without type var" do
    nodes = parse %(
      Pointer.malloc(1)
    )
    lambda {
      infer_type nodes
    }.should raise_error(Crystal::Exception, regex("can't malloc pointer without type, use Pointer(Type).malloc(size)"))
  end
end
