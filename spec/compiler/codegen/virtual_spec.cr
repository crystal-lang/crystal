require "../../spec_helper"

describe "Code gen: virtual type" do
  it "call base method" do
    run("
      class Foo
        def coco
          1
        end
      end

      class Bar < Foo
      end

      a = Foo.new
      a = Bar.new
      a.coco
    ").to_i.should eq(1)
  end

  it "call overwritten method" do
    run("
      class Foo
        def coco
          1
        end
      end

      class Bar < Foo
        def coco
          2
        end
      end

      a = Foo.new
      a = Bar.new
      a.coco
    ").to_i.should eq(2)
  end

  it "call base overwritten method" do
    run("
      class Foo
        def coco
          1
        end
      end

      class Bar < Foo
        def coco
          2
        end
      end

      a = Bar.new
      a = Foo.new
      a.coco
    ").to_i.should eq(1)
  end

  it "dispatch call with virtual type argument" do
    run("
      class Foo
      end

      class Bar < Foo
      end

      def coco(x : Bar)
        1
      end

      def coco(x)
        2
      end

      a = Bar.new
      a = Foo.new
      coco(a)
    ").to_i.should eq(2)
  end

  it "can belong to union" do
    run("
      class Foo
        def foo; 1; end
      end
      class Bar < Foo; end
      class Baz
        def foo; 2; end
      end

      x = Foo.new
      x = Bar.new
      x = Baz.new
      x.foo
    ").to_i.should eq(2)
  end

  it "lookup instance variables in parent types" do
    run("
      class Foo
        def initialize
          @x = 1
        end
        def foo
          @x
        end
      end

      class Bar < Foo
        def foo
          @x + 1
        end
      end

      a = Bar.new || Foo.new
      a.foo
    ").to_i.should eq(2)
  end

  it "assign instance variable in virtual type" do
    run("
      class Foo
        def foo
          @x = 1
        end
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.foo
    ").to_i.should eq(1)
  end

  it "codegens non-virtual call that calls virtual call to another virtual call" do
    run("
      class Foo
        def foo
          foo2
        end

        def foo2
          1
        end
      end

      class Bar < Foo
        def bar
          foo
        end
      end

      bar = Bar.new
      bar.bar
      ").to_i.should eq(1)
  end

  it "casts virtual type to base virtual type" do
    run("
      class Object
        def bar
          1
        end
      end

      class Foo
        def foo
          bar
        end
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.foo
      ").to_i.should eq(1)
  end

  it "codegens call to Object#to_s from virtual type" do
    run("
      require \"prelude\"

      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      a.to_s
      ")
  end

  it "codegens call to Object#to_s from nilable type" do
    run("
      require \"prelude\"

      class Foo
      end

      a = nil || Foo.new
      a.to_s
      ")
  end

  it "codegens virtual call with explicit self" do
    run("
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.foo
      ").to_i.should eq(1)
  end

  it "codegens virtual call with explicit self and nilable type" do
    run("
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
      end

      struct Nil
        def foo
          2
        end
      end

      f = Bar.new || nil
      f.foo.to_i
      ").to_i.should eq(1)
  end

  it "initializes ivars to nil even if object never instantiated" do
    run("
      require \"prelude\"

      class Foo
        def foo
          bar self
        end
      end

      class Bar < Foo
      end

      class Baz < Foo
        def initialize
          @x = Reference.new
        end

        def x
          @x
        end
      end

      def bar(x)
      end

      def bar(x : Baz)
        x.x.to_s
      end

      f = Foo.new || Bar.new
      f.foo
      ")
  end

  it "doesn't lookup in Value+ when virtual type is Object+" do
    run("
      require \"bool\"
      require \"reference\"

      class Object
        def foo
          !nil?
        end
      end

      class Foo
      end

      a = Foo.new
      a.foo
      ").to_b.should be_true
  end

  it "correctly dispatch call with block when the obj is a virtual type" do
    run("
      class Foo
        def each
          yield self
        end

        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      a = Foo.new
      a = Bar.new

      y = 0
      a.each {|x| y = x.foo}
      y
    ").to_i.should eq(2)
  end

  it "dispatch call with nilable virtual arg" do
    run("
      class Foo
      end

      class Bar < Foo
      end

      def foo(x)
        1
      end

      def foo(x : Bar)
        2
      end

      def lala
        1 == 2 ? nil : Foo.new || Bar.new
      end

      x = lala
      foo(x)
    ").to_i.should eq(1)
  end

  pending "calls class method 1" do
    run("
      class Foo
        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      (Foo.new || Bar.new).class.foo
      ").to_i.should eq(1)
  end

  pending "calls class method 2" do
    run("
      class Foo
        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      (Bar.new || Foo.new).class.foo
      ").to_i.should eq(2)
  end

  pending "calls class method 3" do
    run("
      class Base
        def self.foo
          1
        end
      end

      class Foo < Base
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      (Foo.new || Base.new).class.foo
      ").to_i.should eq(1)
  end

  it "dispatches on virtual metaclass (1)" do
    run("
      class Foo
        def self.coco
          1
        end
      end

      class Bar < Foo
        def self.coco
          2
        end
      end

      some_long_var = Foo || Bar
      some_long_var.coco
      ").to_i.should eq(1)
  end

  it "dispatches on virtual metaclass (2)" do
    run("
      class Foo
        def self.coco
          1
        end
      end

      class Bar < Foo
        def self.coco
          2
        end
      end

      some_long_var = Bar || Foo
      some_long_var.coco
      ").to_i.should eq(2)
  end

  it "dispatches on virtual metaclass (3)" do
    run("
      class Foo
        def self.coco
          1
        end
      end

      class Bar < Foo
        def self.coco
          2
        end
      end

      class Baz < Bar
      end

      some_long_var = Baz || Foo
      some_long_var.coco
      ").to_i.should eq(2)
  end

  it "codegens new for simple type, then for virtual" do
    run("
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
      end

      x = Foo.new(1)
      y = (Foo || Bar).new(1)
      y.x
      ").to_i.should eq(1)
  end

  it "codegens new twice for virtual" do
    run("
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
      end

      y = (Foo || Bar).new(1)
      y = (Foo || Bar).new(1)
      y.x
      ").to_i.should eq(1)
  end

  it "codegens allocate for virtual type with custom new" do
    run("
      class Foo
        def self.new
          allocate
        end

        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      foo = (Bar || Foo).new
      foo.foo
      ").to_i.should eq(2)
  end

  it "returns type with virtual type def type" do
    run("
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      def foo
        return Foo.new if 1 == 1
        Bar.new
      end

      foo.foo
    ").to_i.should eq(1)
  end

  it "casts virtual type to union" do
    run("
      class Foo
      end

      class Bar < Foo
        def foo
          2
        end
      end

      class Baz < Foo
        def foo
          3
        end
      end

      def x(f : Bar | Baz)
        f.foo
      end

      def x(f)
        0
      end

      f = Baz.new || Bar.new
      x(f)
      ").to_i.should eq(3)
  end

  it "casts union to virtual" do
    run("
      module Moo
      end

      abstract class Foo
      end

      class Bar < Foo
        include Moo
      end

      class Baz < Foo
        include Moo
      end

      def foo(x : Moo)
        p = Pointer(Foo).malloc(1_u64)
        p.value = x
        p.value.object_id
      end

      def foo(x)
        0_u64
      end

      reference = Bar.new || Baz.new
      reference.object_id == foo(reference)
      ").to_b.should be_true
  end
end
