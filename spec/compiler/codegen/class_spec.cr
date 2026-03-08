require "../../spec_helper"

describe "Code gen: class" do
  it "codegens call to same instance" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo
          1
        end

        def bar
          foo
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "codegens instance var" do
    run(<<-CRYSTAL).to_i.should eq(42)
      class Foo
        def initialize(@coco : Int32)
        end
        def coco
          @coco
        end
      end

      f = Foo.new(2)
      g = Foo.new(40)
      f.coco &+ g.coco
      CRYSTAL
  end

  it "codegens recursive type" do
    run(<<-CRYSTAL)
      class Foo
        def next=(@next : Foo)
        end
      end

      f = Foo.new
      f.next = f
      CRYSTAL
  end

  it "codegens method call of instance var" do
    run(<<-CRYSTAL).to_f64.should eq(1.0)
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
      CRYSTAL
  end

  it "codegens new which calls initialize" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "codegens method from another method without obj and accesses instance vars" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "codegens virtual call that calls another method" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "codegens virtual method of generic class" do
    run(<<-CRYSTAL).to_i.should eq(1)
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

      Foo(Int32).new.foo.to_i!
      CRYSTAL
  end

  it "changes instance variable in method (ssa bug)" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  # it "gets object_id of class" do
  #   program = Program.new
  #   program.run("Reference.object_id").to_i.should eq(program.reference.metaclass.type_id)
  # end

  it "calls method on Class class" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Class
        def foo
          1
        end
      end

      class Foo
      end

      Foo.foo
      CRYSTAL
  end

  it "uses number type var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo(T)
        def self.foo
          T
        end
      end

      Foo(1).foo
      CRYSTAL
  end

  it "calls class method without self" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def self.coco
          1
        end

        a = coco
      end
      a
      CRYSTAL
  end

  it "calls class method without self (2)" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "assigns type to reference union type" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "does to_s for class" do
    run(<<-CRYSTAL).to_string.should eq("Reference")
      require "prelude"

      Reference.to_s
      CRYSTAL
  end

  it "allows fixing an instance variable's type" do
    run(<<-CRYSTAL).to_b.should be_true
      class Foo
        @x : Bool

        def initialize(@x)
        end

        def x
          @x
        end
      end

      Foo.new(true).x
      CRYSTAL
  end

  it "codegens initialize with instance var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @x : Nil

        def initialize
          @x
        end
      end

      Foo.new
      1
      CRYSTAL
  end

  it "reads other instance var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def initialize(@x : Int32)
        end
      end

      foo = Foo.new(1)
      foo.@x
      CRYSTAL
  end

  it "reads a virtual type instance var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
      end

      foo = Foo.new(1) || Bar.new(2)
      foo.@x
      CRYSTAL
  end

  it "reads a union type instance var (reference union, first type)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar
        def initialize(@y : Int32, @x : Bool)
        end

        def x
          @x
        end
      end

      foo = Foo.new(10)
      bar = Bar.new(2, true)
      union = foo || bar
      var = union.@x
      if var.is_a?(Int32)
        var
      else
        20
      end
      CRYSTAL
  end

  it "reads a union type instance var (reference union, second type)" do
    run(<<-CRYSTAL).to_i.should eq('a'.ord)
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar
        def initialize(@y : Int32, @x : Char)
        end

        def x
          @x
        end
      end

      foo = Foo.new(10)
      bar = Bar.new(2, 'a')
      union = bar || foo
      var = union.@x
      if var.is_a?(Char)
        var
      else
        'b'
      end
      CRYSTAL
  end

  it "reads a union type instance var (mixed union, first type)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar
        def initialize(@y : Int32, @x : Bool)
        end

        def x
          @x
        end
      end

      foo = Foo.new(10)
      bar = Bar.new(2, true)
      union = foo || bar
      var = union.@x
      if var.is_a?(Int32)
        var
      else
        20
      end
      CRYSTAL
  end

  it "reads a union type instance var (mixed union, second type)" do
    run(<<-CRYSTAL).to_i.should eq('a'.ord)
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar
        def initialize(@y : Int32, @x : Char)
        end

        def x
          @x
        end
      end

      foo = Foo.new(10)
      bar = Bar.new(2, 'a')
      union = bar || foo
      var = union.@x
      if var.is_a?(Char)
        var
      else
        'b'
      end
      CRYSTAL
  end

  it "never considers read instance var as closure (#12181)" do
    codegen(<<-CRYSTAL)
      class Foo
        @x = 1
      end

      def bug
        ->{
          Foo.new.@x
        }
      end

      bug
      CRYSTAL
  end

  it "runs with nilable instance var" do
    run(<<-CRYSTAL).to_i.should eq(0)
      struct Nil
        def to_i!
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
      bar.x.to_i!
      CRYSTAL
  end

  it "runs with nil instance var when inheriting" do
    run(<<-CRYSTAL).to_i.should eq(0)
      struct Nil
        def to_i!
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
      bar.x.to_i!
      CRYSTAL
  end

  it "codegens bug #168" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "allows initializing var with constant" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        A = 1
        @x = A

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "codegens class method" do
    codegen(<<-CRYSTAL)
      Int32.class
      CRYSTAL
  end

  it "codegens virtual class method" do
    codegen(<<-CRYSTAL)
      class Foo
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).class
      CRYSTAL
  end

  it "allows using self in class scope" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "allows using self in class scope" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

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
      CRYSTAL
  end

  it "makes .class always be a virtual type even if no subclasses" do
    codegen(<<-CRYSTAL)
      class Foo
      end

      p = Pointer(Foo.class).malloc(1_u64)

      class Bar < Foo
        p.value = self
      end
      CRYSTAL
  end

  it "does to_s for virtual metaclass type (1)" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      require "prelude"

      class Foo; end
      class Bar < Foo; end
      class Baz < Foo; end

      a = Foo || Bar || Baz
      a.to_s
      CRYSTAL
  end

  it "does to_s for virtual metaclass type (2)" do
    run(<<-CRYSTAL).to_string.should eq("Bar")
      require "prelude"

      class Foo; end
      class Bar < Foo; end
      class Baz < Foo; end

      a = Bar || Foo || Baz
      a.to_s
      CRYSTAL
  end

  it "does to_s for virtual metaclass type (3)" do
    run(<<-CRYSTAL).to_string.should eq("Baz")
      require "prelude"

      class Foo; end
      class Bar < Foo; end
      class Baz < Foo; end

      a = Baz || Bar || Foo
      a.to_s
      CRYSTAL
  end

  it "does not combine module metaclass types with same name but different file scopes (#15503)" do
    run(<<-CRYSTAL, Int32, filename: "foo.cr").should eq(11)
      module Foo
        def self.foo
          1
        end
      end

      alias Bar = Foo

      {% Bar %} # forces immediate resolution of `Bar`

      private module Foo
        def self.foo
          10
        end
      end

      module Baz
        def self.foo
          100
        end
      end

      def foo(x)
        x.foo
      end

      foo(Foo || Baz) &+ foo(Bar || Baz)
      CRYSTAL
  end

  it "does not combine virtual types with same name but different file scopes" do
    run(<<-CRYSTAL, Int32, filename: "foo.cr").should eq(101)
      class Foo
        def foo
          1
        end
      end

      class Bar1 < Foo
        def foo
          10
        end
      end

      alias Fred = Foo
      {% Fred %} # forces immediate resolution of `Foo`

      private class Foo
        def foo
          100
        end
      end

      private class Bar2 < Foo
        def foo
          1000
        end
      end

      Fred.new.as(Fred).foo &+ Foo.new.as(Foo).foo
      CRYSTAL
  end

  it "does not combine virtual metaclass types with same name but different file scopes" do
    run(<<-CRYSTAL, Int32, filename: "foo.cr").should eq(101)
      class Foo
        def self.foo
          1
        end
      end

      class Bar1 < Foo
        def self.foo
          10
        end
      end

      alias Fred = Foo
      {% Fred %} # forces immediate resolution of `Foo`

      private class Foo
        def self.foo
          100
        end
      end

      private class Bar2 < Foo
        def self.foo
          1000
        end
      end

      Fred.as(Fred.class).foo &+ Foo.as(Foo.class).foo
      CRYSTAL
  end

  it "does not combine generic virtual metaclass types with same name but different file scopes" do
    run(<<-CRYSTAL, Int32, filename: "foo.cr").should eq(11)
      module Foo
        def self.foo
          1
        end
      end

      alias Bar = Foo

      {% Bar %} # forces immediate resolution of `Bar`

      private module Foo
        def self.foo
          10
        end
      end

      abstract class Base
      end

      class Gen(T) < Base
        def self.x
          T.foo
        end
      end

      Gen(Foo).as(Base.class).x &+ Gen(Bar).as(Base.class).x
      CRYSTAL
  end

  it "does not combine generic module metaclass types with same name but different file scopes" do
    run(<<-CRYSTAL, Int32, filename: "foo.cr").should eq(11)
      module Foo
        def self.foo
          1
        end
      end

      alias Bar = Foo

      {% Bar %} # forces immediate resolution of `Bar`

      private module Foo
        def self.foo
          10
        end
      end

      module Gen(T)
        def self.x
          T.foo
        end
      end

      (Gen(Foo) || Gen(Bar)).x &+ (Gen(Bar) || Gen(Foo)).x
      CRYSTAL
  end

  it "builds generic class bug" do
    codegen(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "resolves type declaration when accessing instance var (#348)" do
    codegen(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "gets class of virtual type" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "notifies superclass recursively on inheritance (#576)" do
    run(<<-CRYSTAL).to_string.should eq("Qux")
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
      CRYSTAL
  end

  it "works with array in variable initializer in non-generic type (#855)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      require "prelude"

      class Foo
        @ary = [1, 2, 3]

        def sum
          @ary.sum
        end
      end

      Foo.new.sum
      CRYSTAL
  end

  it "works with array in variable initializer in generic type (#855)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      require "prelude"

      class Foo(T)
        @ary = [1, 2, 3]

        def sum
          @ary.sum
        end
      end

      Foo(Int32).new.sum
      CRYSTAL
  end

  it "doesn't crash on instance variable assigned a proc, and never instantiated (#923)" do
    codegen(<<-CRYSTAL)
      class Klass
        def self.f(arg)
        end

        @a : Proc(String, Nil) = ->f(String)
      end
      CRYSTAL
  end

  it "does to_s on class" do
    run(<<-CRYSTAL).to_string.should eq("Class")
      require "prelude"

      class Foo
      end

      Foo.class.to_s
      CRYSTAL
  end

  it "invokes class method inside instance method (#1119)" do
    run(<<-CRYSTAL).to_i.should eq(123)
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
      CRYSTAL
  end

  it "codegens method of class union including Int (#1476)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Class
        def foo
          1
        end
      end

      x = Int || Int32
      x.foo
      CRYSTAL
  end

  it "can use a Main class (#1628)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      class Main
        def self.foo
          1
        end
      end

      Main.foo
      CRYSTAL
  end

  it "codegens singleton (#718)" do
    run(<<-CRYSTAL).to_string.should eq("Hello")
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
      CRYSTAL
  end

  it "doesn't crash if not using undefined instance variable in superclass" do
    run(<<-CRYSTAL).to_i.should eq(42)
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
      CRYSTAL
  end

  it "codegens virtual metaclass union bug (#2597)" do
    run(<<-CRYSTAL).to_i.should eq(2)

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
      CRYSTAL
  end

  it "doesn't crash on #1216" do
    codegen(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "doesn't crash on #1216 with pointerof" do
    codegen(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "doesn't crash on #1216 (reduced)" do
    codegen(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "doesn't crash on abstract class never instantiated (#2840)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      abstract class Foo
      end

      if 1 == 2
        true
      else
        Pointer(Foo).malloc(1_u64).value.foo
      end
      CRYSTAL
  end

  it "can assign virtual metaclass to virtual metaclass (#3007)" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "transfers initializer from module to generic class" do
    run(<<-CRYSTAL).to_i.should eq(123)
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
      CRYSTAL
  end

  it "transfers initializer from generic module to non-generic class" do
    run(<<-CRYSTAL).to_i.should eq(123)
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
      CRYSTAL
  end

  it "transfers initializer from generic module to generic class" do
    run(<<-CRYSTAL).to_i.should eq(123)
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
      CRYSTAL
  end

  it "doesn't skip false initializers (#3272)" do
    run(<<-CRYSTAL).to_i.should eq(20)
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
      CRYSTAL
  end

  it "doesn't skip zero initializers (#3272)" do
    run(<<-CRYSTAL).to_i.should eq(0)
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
      CRYSTAL
  end

  it "codegens virtual generic class instance metaclass (#3819)" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
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
      CRYSTAL
  end

  it "codegens class with recursive tuple to class (#4520)" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(1)
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
      CRYSTAL
  end

  it "runs instance variable initializer at the class level" do
    run(<<-CRYSTAL).to_i.should eq(42)
      class Foo
        @x : Int32 = bar

        def self.bar
          42
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "runs instance variable initializer at the class level, for generic type" do
    run(<<-CRYSTAL).to_i.should eq(42)
      class Foo(T)
        @x : T = bar

        def self.bar
          42
        end

        def x
          @x
        end
      end

      Foo(Int32).new.x
      CRYSTAL
  end

  pending "codegens assignment of generic metaclasses (1) (#10394)" do
    run(<<-CRYSTAL).to_string.should eq("Bar(T)")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Foo(T); end
      class Bar(T) < Foo(T); end

      x = Foo
      x = Bar
      x.name
      CRYSTAL
  end

  pending "codegens assignment of generic metaclasses (2) (#10394)" do
    run(<<-CRYSTAL).to_string.should eq("Bar(Int32)")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Foo(T); end
      class Bar(T) < Foo(T); end

      x = Foo
      x = Bar(Int32)
      x.name
      CRYSTAL
  end

  it "codegens assignment of generic metaclasses (3) (#10394)" do
    run(<<-CRYSTAL).to_string.should eq("Bar(Int32)")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Foo(T); end
      class Bar(T) < Foo(T); end

      x = Foo(Int32)
      x = Bar(Int32)
      x.name
      CRYSTAL
  end

  it "codegens assignment of generic metaclasses (4) (#10394)" do
    run(<<-CRYSTAL).to_string.should eq("Bar(Int32)")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Foo(T); end
      class Bar(T) < Foo(T); end

      x = Foo(String)
      x = Bar(Int32)
      x.name
      CRYSTAL
  end

  it "codegens assignment of generic metaclasses, base is non-generic (1) (#10394)" do
    run(<<-CRYSTAL).to_string.should eq("Bar(T)")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Foo; end
      class Bar(T) < Foo; end

      x = Foo
      x = Bar
      x.name
      CRYSTAL
  end

  it "codegens assignment of generic metaclasses, base is non-generic (2) (#10394)" do
    run(<<-CRYSTAL).to_string.should eq("Bar(Int32)")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Foo; end
      class Bar(T) < Foo; end

      x = Foo
      x = Bar(Int32)
      x.name
      CRYSTAL
  end
end
