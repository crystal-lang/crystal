require 'spec_helper'

describe 'Type inference: def overload' do
  it "types a call with overload" do
    assert_type('def foo; 1; end; def foo(x); 2.5; end; foo') { int }
  end

  it "types a call with overload with yield" do
    assert_type('def foo; yield; 1; end; def foo; 2.5; end; foo') { float }
  end

  it "types a call with overload with yield the other way" do
    assert_type('def foo; yield; 1; end; def foo; 2.5; end; foo { 1 }') { int }
  end

  it "types a call with overload type first overload" do
    assert_type('def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1)') { float }
  end

  it "types a call with overload type second overload" do
    assert_type('def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1.5)') { int }
  end

  it "types a call with overload Object type first overload" do
    assert_type('class Foo; end; class Bar; end; def foo(x : Foo); 2.5; end; def foo(x : Bar); 1; end; foo(Foo.new)') { float }
  end

  it "types a call with overload Object type first overload" do
    assert_type(%q(
      class Foo
        def initialize
          @x = 1
        end
      end
      class Bar
      end

      def foo(x : Foo); 2.5; end; def foo(x : Bar); 1; end; foo(Foo.new)
      )) { float }
  end

  it "types a call with overload selecting the most restrictive" do
    assert_type('def foo(x); 1; end; def foo(x : Float); 1.1; end; foo(1.5)') { float }
  end

  it "types a call with overload selecting the most restrictive" do
    assert_type(%Q(
      def foo(x, y : Int)
        1
      end

      def foo(x : Int, y)
        1.1
      end

      def foo(x : Int, y : Int)
        'a'
      end

      foo(1, 1)
    )) { char }
  end
end
