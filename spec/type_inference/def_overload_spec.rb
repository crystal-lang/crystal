require 'spec_helper'

describe 'Type inference: def overload' do
  it "types a call with overload" do
    assert_type('def foo; 1; end; def foo(x); 2.5; end; foo') { int }
  end

  it "types a call with overload with yield" do
    assert_type('def foo; yield; 1; end; def foo; 2.5; end; foo') { double }
  end

  it "types a call with overload with yield after typing another call without yield" do
    assert_type(%q(
      def foo; yield; 1; end
      def foo; 2.5; end
      foo
      foo {}
    )) { int }
  end

  it "types a call with overload with yield the other way" do
    assert_type('def foo; yield; 1; end; def foo; 2.5; end; foo { 1 }') { int }
  end

  it "types a call with overload type first overload" do
    assert_type('def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1)') { double }
  end

  it "types a call with overload type second overload" do
    assert_type('def foo(x : Int); 2.5; end; def foo(x : Double); 1; end; foo(1.5)') { int }
  end

  it "types a call with overload Object type first overload" do
    assert_type('class Foo; end; class Bar; end; def foo(x : Foo); 2.5; end; def foo(x : Bar); 1; end; foo(Foo.new)') { double }
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
      )) { double }
  end

  it "types a call with overload selecting the most restrictive" do
    assert_type('def foo(x); 1; end; def foo(x : Double); 1.1; end; foo(1.5)') { double }
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

  it "types a call with overload matches hierarchy" do
    assert_type(%Q(
      class A; end

      def foo(x : Object)
        1
      end

      foo(A.new)
    )) { int }
  end

  it "types a call with overload matches hierarchy 2" do
    assert_type(%Q(
      class A
      end

      class B < A
      end

      def foo(x : A)
        1
      end

      def foo(x : B)
        1.5
      end

      foo(B.new)
    )) { double }
  end

  it "types a call with overload matches hierarchy 3" do
    assert_type(%Q(
      class A
      end

      class B < A
      end

      def foo(x : A)
        1
      end

      def foo(x : B)
        1.5
      end

      foo(A.new)
    )) { int }
  end

  it "types a call with overload self" do
    assert_type(%Q(
      class A
        def foo(x : self)
          1
        end

        def foo(x)
          1.5
        end
      end

      a = A.new
      a.foo(a)
    )) { int }
  end

  it "types a call with overload self other match" do
    assert_type(%Q(
      class A
        def foo(x : self)
          1
        end

        def foo(x)
          1.5
        end
      end

      a = A.new
      a.foo(1)
    )) { double }
  end

  it "types a call with overload self in included module" do
    assert_type(%Q(
      module Foo
        def foo(x : self)
          1
        end
      end

      class A
        def foo(x)
          1.5
        end
      end

      class B < A
        include Foo
      end

      b = B.new
      b.foo(b)
    )) { int }
  end

  it "types a call with overload self in included module other type" do
    assert_type(%Q(
      module Foo
        def foo(x : self)
          1
        end
      end

      class A
        def foo(x)
          1.5
        end
      end

      class B < A
        include Foo
      end

      b = B.new
      b.foo(A.new)
    )) { double }
  end

  it "types a call with overload self with inherited type" do
    assert_type(%Q(
      class A
        def foo(x : self)
          1
        end
      end

      class B < A
      end

      a = A.new
      a.foo(B.new)
    )) { int }
  end

  it "matches types with free variables" do
    assert_type(%Q(
      require "array"
      def foo(x : Array(T), y : T)
        1
      end

      def foo(x, y)
        1.5
      end

      foo([1], 1)
    )) { int }
  end

  it "prefer more specifc overload than one with free variables" do
    assert_type(%Q(
      require "array"
      def foo(x : Array(T), y : T)
        1
      end

      def foo(x : Array(Int), y : Int)
        1.5
      end

      foo([1], 1)
    )) { double }
  end

  it "accept overload with nilable type restriction" do
    assert_type(%Q(
      def foo(x : Int?)
        1
      end

      foo(1)
    )) { int }
  end

  it "dispatch call to def with restrictions" do
    assert_type(%Q(
      def foo(x : Value)
        1.1
      end

      def foo(x : Int)
        1
      end

      a = 1; a = 1.1
      foo(a)
    )) { union_of(int, double) }
  end

  it "dispatch call to def with restrictions" do
    assert_type(%Q(
      class Foo(T)
      end

      def foo(x : T)
        Foo(T).new
      end

      foo 1
    )) { ObjectType.new("Foo").of("T" => int) }
  end

  it "can call overload with generic restriction" do
    assert_type(%q(
      class Foo(T)
      end

      def foo(x : Foo)
        1
      end

      foo(Foo(Int).new)
    )) { int }
  end

  it "restrict matches to minimum necessary 1" do
    assert_type(%q(
      def coco(x : Int, y); 1; end
      def coco(x, y : Int); 1.5; end
      def coco(x, y); 'a'; end

      coco 1, 1
    )) { int }
  end

  it "single type restriction wins over union" do
    assert_type(%q(
      class Foo; end
      class Bar < Foo ;end

      def foo(x : Foo | Bar)
        1.1
      end

      def foo(x : Foo)
        1
      end

      foo(Foo.new || Bar.new)
    )) { int }
  end

  it "compare self type with others" do
    assert_type(%q(
      class Foo
        def foo(x : Int)
          1.1
        end

        def foo(x : self)
          1
        end
      end

      x = Foo.new.foo(Foo.new)
    )) { int }
  end

  it "uses method defined in base class if the restriction doesn't match" do
    assert_type(%q(
      class Foo
        def foo(x)
          1
        end
      end

      class Bar < Foo
        def foo(x : Double)
          1.1
        end
      end

      Bar.new.foo(1)
    )) { int }
  end
end
