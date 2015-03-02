require "../../spec_helper"

describe "Code gen: class" do
  it "codegens instace method with allocate" do
    run("class Foo; def coco; 1; end; end; Foo.allocate.coco").to_i.should eq(1)
  end

  it "codegens instace method with new and instance var" do
    run("class Foo; def initialize; @coco = 2; end; def coco; @coco = 1; @coco; end; end; f = Foo.new; f.coco").to_i.should eq(1)
  end

  it "codegens instace method with new" do
    run("class Foo; def coco; 1; end; end; Foo.new.coco").to_i.should eq(1)
  end

  it "codegens call to same instance" do
    run("class Foo; def foo; 1; end; def bar; foo; end; end; Foo.new.bar").to_i.should eq(1)
  end

  it "codegens instance var" do
    run("
      class Foo
        def initialize(@coco)
        end
        def coco
          @coco
        end
      end

      f = Foo.new(2)
      g = Foo.new(40)
      f.coco + g.coco
      ").to_i.should eq(42)
  end

  it "codegens recursive type" do
    run("
      class Foo
        def next=(@next)
        end
      end

      f = Foo.new
      f.next = f
      ")
  end

  it "codegens method call of instance var" do
    run("
      class List
        def initialize
          @last = 0
        end

        def foo
          @last = 1
          @last.to_f
        end
      end

      l = List.new
      l.foo
      ").to_f64.should eq(1.0)
  end

  it "codegens new which calls initialize" do
    run("
      class Foo
        def initialize(value)
          @value = value
        end

        def value
          @value
        end
      end

      f = Foo.new 1
      f.value
    ").to_i.should eq(1)
  end

  it "codegens method from another method without obj and accesses instance vars" do
    run("
      class Foo
        def foo
          bar
        end

        def bar
          @a = 1
        end
      end

      f = Foo.new
      f.foo
      ").to_i.should eq(1)
  end

  it "codegens virtual call that calls another method" do
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
      end

      Bar.new.foo
      ").to_i.should eq(1)
  end

  it "codgens virtual method of generic class" do
    run("
      require \"char\"

      class Object
        def foo
          bar
        end

        def bar
          'a'
        end
      end

      class Foo(T)
        def bar
          1
        end
      end

      Foo(Int32).new.foo.to_i
      ").to_i.should eq(1)
  end

  it "changes instance variable in method (ssa bug)" do
    run("
      class Foo
        def initialize
          @var = 0
        end

        def foo
          @var = 1
          bar
          @var
        end

        def bar
          @var = 2
        end
      end

      foo = Foo.new
      foo.foo
      ").to_i.should eq(2)
  end

  # it "gets object_id of class" do
  #   program = Program.new
  #   program.run("Reference.object_id").to_i.should eq(program.reference.metaclass.type_id)
  # end

  it "calls method on Class class" do
    run("
      class Class
        def foo
          1
        end
      end

      class Foo
      end

      Foo.foo
    ").to_i.should eq(1)
  end

  it "uses number type var" do
    run("
      class Foo(T)
        def self.foo
          T
        end
      end

      Foo(1).foo
      ").to_i.should eq(1)
  end

  it "calls class method without self" do
    run("
      class Foo
        def self.coco
          1
        end

        a = coco
      end
      a
      ").to_i.should eq(1)
  end

  it "calls class method without self (2)" do
    run("
      class Foo
        def self.coco
          lala
        end

        def self.lala
          1
        end
      end

      class Bar < Foo
        def self.lala
          2
        end

        a = coco
      end
      a
      ").to_i.should eq(2)
  end

  it "assigns type to reference union type" do
    run("
      class Foo
        def initialize(@x)
        end
        def x=(@x); end
      end

      class Bar; end
      class Baz; end

      f = Foo.new(Bar.new)
      f.x = Baz.new
      1
      ").to_i.should eq(1)
  end

  it "does to_s for class" do
    run(%(
      require "prelude"

      Reference.to_s
      )).to_string.should eq("Reference")
  end

  it "allows fixing an instance variable's type" do
    run(%(
      class Foo
        @x :: Bool

        def initialize(@x)
        end

        def x
          @x
        end
      end

      Foo.new(true).x
      )).to_b.should be_true
  end

  it "codegens initialize with instance var" do
    run(%(
      class Foo
        def initialize
          @x
        end
      end

      Foo.new
      1
      )).to_i.should eq(1)
  end

  it "reads other instance var" do
    run(%(
      class Foo
        def initialize(@x)
        end
      end

      foo = Foo.new(1)
      foo.@x
      )).to_i.should eq(1)
  end

  it "reads a virtual type instance var" do
    run(%(
      class Foo
        def initialize(@x)
        end
      end

      class Bar < Foo
      end

      foo = Foo.new(1) || Bar.new(2)
      foo.@x
      )).to_i.should eq(1)
  end

  it "runs with nil instance var" do
    run("
      struct Nil
        def to_i
          0
        end
      end

      class Bar
        def initialize
        end

        def initialize(@x)
        end

        def x
          @x
        end
      end

      bar = Bar.new
      bar.x.to_i
      ").to_i.should eq(0)
  end

  it "runs with nil instance var when inheriting" do
    run("
      struct Nil
        def to_i
          0
        end
      end

      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize
        end
      end

      bar = Bar.new
      bar.x.to_i
      ").to_i.should eq(0)
  end

  it "codegens bug #168" do
    run("
      class A
        def foo
          x = @x
          if x
            x.foo
          else
            1
          end
        end
      end

      class B < A
        def initialize(@x)
        end
      end

      B.new(A.new).foo
      ").to_i.should eq(1)
  end

  it "allows initializing var with constant" do
    run(%(
      class Foo
        A = 1
        @x = A

        def x
          @x
        end
      end

      Foo.new.x
      )).to_i.should eq(1)
  end

  it "codegens class method" do
    build(%(
      Int32.class
      ))
  end

  it "codegens virtual class method" do
    build(%(
      class Foo
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).class
      ))
  end

  it "allows using self in class scope" do
    run(%(
      class Foo
        def self.foo
          1
        end

        $x = self.foo
      end

      $x
      )).to_i.should eq(1)
  end

  it "allows using self in class scope" do
    run(%(
      class Foo
        def self.foo
          1
        end

        $x = self
      end

      $x.foo
      )).to_i.should eq(1)
  end

  it "makes .class always be a virtual type even if no subclasses" do
    build(%(
      class Foo
      end

      p = Pointer(Foo.class).malloc(1_u64)

      class Bar < Foo
        p.value = self
      end
      ))
  end

  it "does to_s for virtual metaclass type (1)" do
    run(%(
      require "prelude"

      class Foo; end
      class A < Foo; end
      class B < Foo; end

      a = Foo || A || B
      a.to_s
      )).to_string.should eq("Foo")
  end

  it "does to_s for virtual metaclass type (2)" do
    run(%(
      require "prelude"

      class Foo; end
      class A < Foo; end
      class B < Foo; end

      a = A || Foo || B
      a.to_s
      )).to_string.should eq("A")
  end

  it "does to_s for virtual metaclass type (3)" do
    run(%(
      require "prelude"

      class Foo; end
      class A < Foo; end
      class B < Foo; end

      a = B || A || Foo
      a.to_s
      )).to_string.should eq("B")
  end

  it "does to_s for virtual metaclass type (4)" do
    run(%(
      require "prelude"

      class Foo; end
      class A < Foo; end
      class B < Foo; end

      class Obj(T)
        def self.t
          T
        end
      end

      t = Obj(Foo+).t
      t.to_s
      )).to_string.should eq("Foo")
  end

  it "builds generic class bug" do
    build(%(
      abstract class Base
        def initialize
          @value = 1
        end
      end

      class Foo(T) < Base
        def foo
          @target
        end
      end

      class Bar < Base
        def foo
        end
      end

      ex = Foo(Int32).new || Bar.new
      ex.foo
      ))
  end

  it "resolves type declaration when accessing instance var (#348)" do
    build(%(
      require "prelude"

      lib LibC
        type Foo = Int64[8]
      end

      class Bar
        def initialize
          @foo :: LibC::Foo
        end
      end

      Bar.new.inspect
      ))
  end

  it "gets class of virtual type" do
    run(%(
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

      f = Bar.new || Foo.new
      f.class.foo
      )).to_i.should eq(2)
  end
end
