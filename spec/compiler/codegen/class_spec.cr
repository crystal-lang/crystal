require "../../spec_helper"

describe "Code gen: class" do
  it "codegens call to same instance" do
    run(%(
      class Foo
        def foo
          1
        end

        def bar
          foo
        end
      end

      Foo.new.bar
      )).to_i.should eq(1)
  end

  it "codegens instance var" do
    run("
      class Foo
        def initialize(@coco : Int32)
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
        def next=(@next : Foo)
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
        def initialize(value : Int32)
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
        def initialize(@x : Bar)
        end
        def x=(@x : Baz); end
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
        @x : Bool

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
        @x : Nil

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
        def initialize(@x : Int32)
        end
      end

      foo = Foo.new(1)
      foo.@x
      )).to_i.should eq(1)
  end

  it "reads a virtual type instance var" do
    run(%(
      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
      end

      foo = Foo.new(1) || Bar.new(2)
      foo.@x
      )).to_i.should eq(1)
  end

  it "runs with nilable instance var" do
    run("
      struct Nil
        def to_i
          0
        end
      end

      class Bar
        def initialize
        end

        def initialize(@x : Int32?)
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
        @x : Int32?

        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize
          @x = nil
        end
      end

      bar = Bar.new
      bar.x.to_i
      ").to_i.should eq(0)
  end

  it "codegens bug #168" do
    run("
      class Foo
        @x : Foo?

        def foo
          x = @x
          if x
            x.foo
          else
            1
          end
        end
      end

      class Bar < Foo
        def initialize(@x)
        end
      end

      Bar.new(Foo.new).foo
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
    codegen(%(
      Int32.class
      ))
  end

  it "codegens virtual class method" do
    codegen(%(
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

        @@x = self.foo.as(Int32)

        def self.x
          @@x
        end
      end

      Foo.x
      )).to_i.should eq(1)
  end

  it "allows using self in class scope" do
    run(%(
      class Foo
        def self.foo
          1
        end

        @@x = self.as(Foo.class)

        def self.x
          @@x
        end
      end

      Foo.x.foo
      )).to_i.should eq(1)
  end

  it "makes .class always be a virtual type even if no subclasses" do
    codegen(%(
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
      class Bar < Foo; end
      class Baz < Foo; end

      a = Foo || Bar || Baz
      a.to_s
      )).to_string.should eq("Foo")
  end

  it "does to_s for virtual metaclass type (2)" do
    run(%(
      require "prelude"

      class Foo; end
      class Bar < Foo; end
      class Baz < Foo; end

      a = Bar || Foo || Baz
      a.to_s
      )).to_string.should eq("Bar")
  end

  it "does to_s for virtual metaclass type (3)" do
    run(%(
      require "prelude"

      class Foo; end
      class Bar < Foo; end
      class Baz < Foo; end

      a = Baz || Bar || Foo
      a.to_s
      )).to_string.should eq("Baz")
  end

  it "builds generic class bug" do
    codegen(%(
      abstract class Base
        def initialize
          @value = 1
        end
      end

      class Foo(T) < Base
        @target : Nil

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
    codegen(%(
      require "prelude"

      lib LibC
        type Foo = Int64[8]
      end

      class Bar
        def initialize
          @foo = uninitialized LibC::Foo
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

  it "notifies superclass recursively on inheritance (#576)" do
    run(%(
      class Class
        def name : String
          {{ @type.name.stringify }}
        end

        def foo
          name
        end
      end

      class Foo
      end

      ptr = Pointer(Foo.class).malloc(1_u64)
      ptr.value = Foo
      ptr.value.foo

      class Bar < Foo; end
      ptr.value = Bar
      ptr.value.foo

      class Baz < Bar; end
      ptr.value = Baz
      ptr.value.foo

      class Qux < Baz; end
      ptr.value = Qux
      ptr.value.foo
      )).to_string.should eq("Qux")
  end

  it "works with array in variable initializer in non-generic type (#855)" do
    run(%(
      require "prelude"

      class Foo
        @ary = [1, 2, 3]

        def sum
          @ary.sum
        end
      end

      Foo.new.sum
      )).to_i.should eq(6)
  end

  it "works with array in variable initializer in generic type (#855)" do
    run(%(
      require "prelude"

      class Foo(T)
        @ary = [1, 2, 3]

        def sum
          @ary.sum
        end
      end

      Foo(Int32).new.sum
      )).to_i.should eq(6)
  end

  it "doesn't crash on instance variable assigned a proc, and never instantiated (#923)" do
    codegen(%(
      class Klass
        def f(arg)
        end

        @a : Proc(String, Nil) = ->f(String)
      end
      ))
  end

  it "does to_s on class" do
    run(%(
      require "prelude"

      class Foo
      end

      Foo.class.to_s
      )).to_string.should eq("Class")
  end

  it "invokes class method inside instance method (#1119)" do
    run(%(
      class Class
        def bar
          123
        end
      end

      class Foo
        def test
          Foo.class
        end
      end

      x = Foo.new.test
      x.bar
      )).to_i.should eq(123)
  end

  it "codegens method of class union including Int (#1476)" do
    run(%(
      class Class
        def foo
          1
        end
      end

      x = Int || Int32
      x.foo
      )).to_i.should eq(1)
  end

  it "can use a Main class (#1628)" do
    run(%(
      require "prelude"

      class Main
        def self.foo
          1
        end
      end

      Main.foo
      )).to_i.should eq(1)
  end

  it "codegens singleton (#718)" do
    run(%(
      class Singleton
        @@instance = new

        def initialize
          @msg = "Hello"
        end

        def msg
          @msg
        end

        def self.get_instance
          @@instance
        end
      end

      Singleton.get_instance.msg
      )).to_string.should eq("Hello")
  end

  it "doesn't crash if not using undefined instance variable in superclass" do
    run(%(
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize(@x : Int32)
        end
      end

      foo = Bar.new(42)
      foo.x
      )).to_i.should eq(42)
  end

  it "codegens virtual metaclass union bug (#2597)" do
    run(%(

      class Foo
        def self.foo
          1
        end
      end

      class Foo1 < Foo
        def self.foo
          2
        end
      end

      class Foo2 < Foo
        def self.foo
          3
        end
      end

      class Bar
        @foo : Foo.class

        def initialize
          @foo = if 1 == 1
                   Foo1
                 elsif 1 == 2
                   Foo2
                 else
                   Foo
                 end
        end

        def foo
          @foo
        end
      end

      Bar.new.foo.foo
      )).to_i.should eq(2)
  end

  it "doesn't crash on #1216" do
    codegen(%(
      class Foo
        def initialize(@ivar : Int32)
          meth
        end

        def meth
          r = self.class.new(5)
          r.@ivar
        end
      end

      Foo.new(6)
      ))
  end

  it "doesn't crash on #1216 with pointerof" do
    codegen(%(
      class Foo
        def initialize(@ivar : Int32)
          meth
        end

        def meth
          r = self.class.new(5)
          pointerof(r.@ivar)
        end
      end

      Foo.new(6)
      ))
  end

  it "doesn't crash on #1216 (reduced)" do
    codegen(%(
      class Foo
        def foo
          crash.foo
        end
      end

      def crash
        x = Foo.allocate
        x.foo
        x
      end

      crash
      ))
  end

  it "doesn't crash on abstract class never instantiated (#2840)" do
    codegen(%(
      require "prelude"

      abstract class Foo
      end

      if 1 == 2
        true
      else
        Pointer(Foo).malloc(1_u64).value.foo
      end
      ))
  end

  it "can assign virtual metaclass to virtual metaclass (#3007)" do
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

      class Baz < Bar
        def self.foo
          3
        end
      end

      class Gen(T)
        def initialize(x : T)
        end
      end

      ptr = Pointer(Foo.class).malloc(1_u64)
      ptr.value = Bar || Baz
      ptr.value.foo
      )).to_i.should eq(2)
  end

  it "transfers initializer from module to generic class" do
    run(%(
      module Moo
        @x = 123

        def x
          @x
        end
      end

      class Foo(T)
        include Moo
      end

      Foo(Int32).new.x
      )).to_i.should eq(123)
  end

  it "transfers initializer from generic module to non-generic class" do
    run(%(
      module Moo(T)
        @x = 123

        def x
          @x
        end
      end

      class Foo
        include Moo(Int32)
      end

      Foo.new.x
      )).to_i.should eq(123)
  end

  it "transfers initializer from generic module to generic class" do
    run(%(
      module Moo(T)
        @x = 123

        def x
          @x
        end
      end

      class Foo(T)
        include Moo(T)
      end

      Foo(Int32).new.x
      )).to_i.should eq(123)
  end

  it "doesn't skip false initializers (#3272)" do
    run(%(
      class Parent
        @foo = true

        def foo
          @foo
        end
      end

      class Child < Parent
        @foo = false
      end

      Child.new.foo ? 10 : 20
      )).to_i.should eq(20)
  end

  it "doesn't skip zero initializers (#3272)" do
    run(%(
      class Parent
        @foo = 123

        def foo
          @foo
        end
      end

      class Child < Parent
        @foo = 0
      end

      Child.new.foo
      )).to_i.should eq(0)
  end

  it "codegens virtual generic class instance metaclass (#3819)" do
    run(%(
      module Core
      end

      class Base(T)
        include Core
      end

      class Foo < Base(String)
      end

      class Bar < Base(Int32)
      end

      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      Foo.new.as(Core).class.name
      )).to_string.should eq("Foo")
  end

  it "codegens class with recursive tuple to class (#4520)" do
    run(%(
      class Foo
        @foo : {Foo, Foo}?

        def initialize(@x : Int32)
        end

        def foo=(@foo)
        end

        def x
          @x
        end
      end

      foo = Foo.new(1)
      foo.foo = {Foo.new(2), Foo.new(3)}
      foo.x
      ), inject_primitives: false).to_i.should eq(1)
  end
end
