require "../../spec_helper"

describe "Code gen: proc" do
  it "call simple proc literal" do
    run("x = -> { 1 }; x.call").to_i.should eq(1)
  end

  it "call proc literal with arguments" do
    run("f = ->(x : Int32) { x &+ 1 }; f.call(41)").to_i.should eq(42)
  end

  it "call proc literal with return type" do
    run(<<-CRYSTAL).to_b.should be_true
      f = -> : Int32 | Float64 { 1 }
      x = f.call
      x.is_a?(Int32) && x == 1
      CRYSTAL
  end

  it "call proc pointer" do
    run("def foo; 1; end; x = ->foo; x.call").to_i.should eq(1)
  end

  it "call proc pointer with args" do
    run("
      def foo(x, y)
        x &+ y
      end

      f = ->foo(Int32, Int32)
      f.call(1, 2)
    ").to_i.should eq(3)
  end

  it "call proc pointer of instance method" do
    run(%(
      class Foo
        def initialize
          @x = 1
        end

        def coco
          @x
        end
      end

      foo = Foo.new
      f = ->foo.coco
      f.call
    )).to_i.should eq(1)
  end

  it "call proc pointer of instance method that raises" do
    run(%(
      require "prelude"
      class Foo
        def coco
          raise "foo"
        end
      end

      foo = Foo.new
      f = ->foo.coco
      f.call rescue 1
    )).to_i.should eq(1)
  end

  it "codegens proc with another var" do
    run("
      def foo(x)
        bar(x, -> {})
      end

      def bar(x, proc)
      end

      foo(1)
      ")
  end

  it "codegens proc that returns a virtual type" do
    run("
      class Foo
        def coco; 1; end
      end

      class Bar < Foo
        def coco; 2; end
      end

      x = -> { Foo.new || Bar.new }
      x.call.coco
      ").to_i.should eq(1)
  end

  it "codegens proc that accepts a union and is called with a single type" do
    run("
      struct Float
        def &+(other)
          self + other
        end
      end

      f = ->(x : Int32 | Float64) { x &+ 1 }
      f.call(1).to_i!
      ").to_i.should eq(2)
  end

  it "makes sure that proc pointer is transformed after type inference" do
    run("
      require \"prelude\"

      class Bar
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Foo
        def on_something
          Bar.new(1)
        end
      end

      def _on_(p : Foo*)
        p.value.on_something.x
      end

      c = ->_on_(Foo*)
      a = Foo.new
      c.call(pointerof(a))
      ").to_i.should eq(1)
  end

  it "binds function pointer to associated call" do
    run("
      class Foo
        def initialize(@e : Int32)
        end

        def on_something
          @e
        end
      end

      def _on_(p : Foo*)
        p.value.on_something
      end

      c = ->_on_(Foo*)
      a = Foo.new(12)
      a.on_something

      c.call(pointerof(a))
      ").to_i.should eq(12)
  end

  it "call simple proc literal with return" do
    run("x = -> { return 1 }; x.call").to_i.should eq(1)
  end

  it "calls proc pointer with union (passed by value) arg" do
    run("
      struct Number
        def abs; self; end
      end

      f = ->(x : Int32 | Float64) { x.abs }
      f.call(1 || 1.5).to_i!
      ").to_i.should eq(1)
  end

  it "allows passing proc type to C automatically" do
    run(%(
      require "prelude"

      lib LibC
        fun qsort(base : Void*, nel : LibC::SizeT, width : LibC::SizeT, callback : (Void*, Void* -> Int32))
      end

      ary = [3, 1, 4, 2]
      LibC.qsort(ary.to_unsafe.as(Void*), LibC::SizeT.new(ary.size), LibC::SizeT.new(sizeof(Int32)), ->(a : Void*, b : Void*) {
        a = a.as(Int32*)
        b = b.as(Int32*)
        a.value <=> b.value
      })
      ary[0]
      )).to_i.should eq(1)
  end

  it "allows proc pointer where self is a class" do
    run("
      class Foo
        def self.bla
          1
        end
      end

      f = ->Foo.bla
      f.call
      ").to_i.should eq(1)
  end

  it "codegens proc literal hard type inference (1)" do
    run(%(
      require "prelude"

      class Foo
        def initialize(@x : NoReturn)
        end

        def x
          @x
        end
      end

      def foo(s)
        Foo.new(s.x)
      end

      def bar
        ->(s : Foo) { ->foo(Foo) }
      end

      bar

      1
      )).to_i.should eq(1)
  end

  it "automatically casts proc that returns something to proc that returns void" do
    run("
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo(x : ->)
        x.call
      end

      foo ->{ Global.x = 1 }

      Global.x
      ").to_i.should eq(1)
  end

  it "allows proc type of enum type" do
    run("
      lib LibFoo
        enum MyEnum
          X = 1
        end
      end

      ->(x : LibFoo::MyEnum) {
        x
      }.call(LibFoo::MyEnum::X)
      ").to_i.should eq(1)
  end

  it "allows proc type of enum type with base type" do
    run("
      lib LibFoo
        enum MyEnum : UInt16
          X = 1
        end
      end

      ->(x : LibFoo::MyEnum) {
        x
      }.call(LibFoo::MyEnum::X)
      ").to_i.should eq(1)
  end

  it "codegens nilable proc type (1)" do
    run("
      a = 1 == 2 ? nil : ->{ 3 }
      if a
        a.call
      else
        4
      end
      ").to_i.should eq(3)
  end

  it "codegens nilable proc type (2)" do
    run("
      a = 1 == 1 ? nil : ->{ 3 }
      if a
        a.call
      else
        4
      end
      ").to_i.should eq(4)
  end

  it "codegens nilable proc type dispatch (1)" do
    run("
      def foo(x : -> U) forall U
        x.call
      end

      def foo(x : Nil)
        0
      end

      a = 1 == 1 ? (->{ 3 }) : nil
      foo(a)
      ").to_i.should eq(3)
  end

  it "codegens nilable proc type dispatch (2)" do
    run("
      def foo(x : -> U) forall U
        x.call
      end

      def foo(x : Nil)
        0
      end

      a = 1 == 1 ? nil : ->{ 3 }
      foo(a)
      ").to_i.should eq(0)
  end

  it "builds proc type from fun" do
    codegen("
      lib LibC
        fun foo : ->
      end

      x = LibC.foo
      x.call
      ")
  end

  it "builds nilable proc type from fun" do
    codegen("
      lib LibC
        fun foo : (->)?
      end

      x = LibC.foo
      if x
        x.call
      end
      ")
  end

  it "assigns nil and proc to nilable proc type" do
    run("
      class Foo
        def initialize
        end

        def x=(@x : (-> Int32)?)
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x = nil
      foo.x = -> { 1 }
      z = foo.x
      if z
        z.call
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "allows invoking proc literal with smaller type" do
    run("
      struct Nil
        def to_i!
          0
        end
      end

      f = ->(x : Int32 | Nil) {
        x
      }
      f.call(1).to_i!
      ").to_i.should eq(1)
  end

  it "does new on proc type" do
    run("
      struct Proc
        def self.new(&block : self)
          block
        end
      end

      alias Func = Int32 -> Int32

      a = 2
      f = Func.new { |x| x &+ a }
      f.call(1)
      ").to_i.should eq(3)
  end

  it "allows invoking a function with a subtype" do
    run(%(
      class Foo
        def x
          1
        end
      end

      class Bar < Foo
        def x
          2
        end
      end

      f = ->(foo : Foo) { foo.x }
      f.call Bar.new
      )).to_i.should eq(2)
  end

  it "allows invoking a function with a subtype when defined as block spec" do
    run(%(
      class Foo
        def x
          1
        end
      end

      class Bar < Foo
        def x
          2
        end
      end

      def func(&block : Foo -> U) forall U
        block
      end

      f = func { |foo| foo.x }
      f.call Bar.new
      )).to_i.should eq(2)
  end

  it "allows redefining fun" do
    run(%(
      fun foo : Int32
        1
      end

      fun foo : Int32
        2
      end

      foo
      )).to_i.should eq(2)
  end

  it "passes block to another function (bug: mangling of both methods was the same)" do
    run(%(
      def foo(&block : ->)
        foo(block)
      end

      def foo(block)
        1
      end

      foo { }
      )).to_i.should eq(1)
  end

  it "codegens proc with union type that returns itself" do
    run(%(
      a = 1 || 1.5

      foo = ->(x : Int32 | Float64) { x }
      foo.call(a)
      foo.call(a).to_i!
      )).to_i.should eq(1)
  end

  it "codegens issue with missing byval in proc literal inside struct" do
    run(%(
      require "prelude"

      struct Params
        def foo
          params = [] of {String}
          params << {"foo"}
          params << {"bar"}
          params.sort! { |x, y| x[0] <=> y[0] }
          params[0][0]
        end
      end

      Params.new.foo
      )).to_string.should eq("bar")
  end

  it "codegens proc that references struct (bug)" do
    run(%(
      class Ref
      end

      class Context
        def initialize
          @x = Ref.new
        end

        def run
          @x.object_id
        end

        def it(&block)
          block.call
        end
      end

      struct Foo
        def initialize
          @x = 0
          @y = 0
          @z = 42
          @w = 0
        end
      end

      context = Context.new
      context.it do
        Foo.new
      end
      context.run
      )).to_i.should_not eq(42)
  end

  it "codegens captured block that returns tuple" do
    codegen(%(
      def foo(&block)
        block
      end

      block = foo do
        {0, 0, 42, 0}
      end
      block.call
      ))
  end

  it "allows using proc arg name shadowing local variable" do
    run(%(
      a = 1
      f = ->(a : String) { }
      a
      )).to_i.should eq(1)
  end

  it "codegens proc that accepts array of type" do
    run(%(
      require "prelude"

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

      def foo(&block : Array(Foo) -> Foo)
        block
      end

      block = foo { |elems| Bar.new }
      elems = [Bar.new, Foo.new]
      bar = block.call elems
      bar.foo
      )).to_i.should eq(2)
  end

  it "gets proc to lib fun (#504)" do
    codegen(%(
      lib LibFoo
        fun bar
      end

      ->LibFoo.bar
      ))
  end

  it "codegens proc to implicit self in constant (#647)" do
    run(%(
      require "prelude"

      module Foo
        def self.blah
          1
        end
        H = ->{ blah }
      end

      Foo::H.call
      )).to_i.should eq(1)
  end

  it "passes proc as &->expr to method that yields" do
    run(%(
      def foo
        yield
      end

      foo &->{ 123 }
      )).to_i.should eq(123)
  end

  it "mangles strings in such a way they don't conflict with funs (#1006)" do
    run(%(
      a = :foo

      fun foo : Int32
        123
      end

      foo
      )).to_i.should eq(123)
  end

  it "gets proc pointer using virtual type (#1337)" do
    run(%(
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

      def foo(a : Foo)
        a.foo
      end

      bar = ->foo(Foo)
      bar.call(Bar.new)
      )).to_i.should eq(2)
  end

  it "uses alias of proc with virtual type (#1347)" do
    run(%(
      require "prelude"

      class Class1
        def foo
          1
        end
      end

      class Class2 < Class1
        def foo
          2
        end
      end

      module Foo
        alias Callback = Class1 ->
        @@callbacks = Hash(String, Callback).new
        def self.add(name, &block : Callback)
          @@callbacks[name] = block
        end

        def self.call
          @@callbacks.each_value(&.call(Class2.new))
        end
      end

      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      Foo.add("foo") do |a|
        Global.x = a.foo
      end

      Foo.call

      Global.x
      )).to_i.should eq(2)
  end

  it "doesn't crash on #2196" do
    run(%(
      x = 42
      z = if x.is_a?(Int32)
        x
      else
        y = x
        ->{ y }
      end
      z.is_a?(Int32) ? z : 0
      )).to_i.should eq(42)
  end

  it "accesses T in macros as a TupleLiteral" do
    run(%(
      struct Proc
        def t
          {{ T.class_name }}
        end
      end

      ->(x : Int32) { 'a' }.t
      )).to_string.should eq("TupleLiteral")
  end

  it "codegens proc in instance var initialize (#3016)" do
    run(%(
      class Foo
        @f : -> Int32 = ->foo

        def self.foo
          42
        end
      end

      Foo.new.@f.call
      )).to_i.should eq(42)
  end

  it "codegens proc of generic type" do
    codegen(%(
      class Gen(T)
      end

      class Foo < Gen(Int32)
      end

      f = ->(x : Gen(Int32)) {}
      f.call(Foo.new)
      ))
  end

  it "executes proc pointer on primitive" do
    run(%(
      a = 1
      f = ->a.&+(Int32)
      f.call(20)
      )).to_i.should eq(21)
  end

  it "can pass Proc(T) to Proc(Nil) in type restriction (#8964)" do
    run(%(
      def foo(x : Proc(Nil))
        x
      end

      a = 1
      proc = foo(->{ a = 2 })
      proc.call
      a
      )).to_i.should eq(2)
  end

  it "can assign proc that returns anything to proc that returns nil (#3655)" do
    run(%(
      class Foo
        @block : -> Nil

        def initialize(@block)
        end

        def call
          @block.call
        end
      end

      a = 1
      block = ->{ a = 2 }

      Foo.new(block).call

      a
      )).to_i.should eq(2)
  end

  it "can assign proc that returns anything to proc that returns nil, using union type (#3655)" do
    run(%(
      class Foo
        @block : -> Nil

        def initialize(@block)
        end

        def call
          @block.call
        end
      end

      a = 1
      block1 = ->{ a = 2 }
      block2 = ->{ a = 3; nil }

      Foo.new(block2 || block1).call

      a
      )).to_i.should eq(3)
  end

  it "calls function pointer" do
    run(%(
      require "prelude"

      fun foo(f : Int32 -> Int32) : Int32
        f.call(1)
      end

      foo(->(x : Int32) { x &+ 1 })
    )).to_i.should eq(2)
  end

  it "casts from function pointer to proc" do
    codegen(%(
      fun a(a : Void* -> Void*)
        Pointer(Proc((Void* -> Void*), Void*)).new(0_u64).value.call(a)
      end
    ))
  end

  it "takes pointerof function pointer" do
    codegen(%(
      fun a(a : Void* -> Void*)
        pointerof(a).value.call(Pointer(Void).new(0_u64))
      end
    ))
  end

  it "closures var on ->var.call (#8584)" do
    run(%(
      def bar(x)
        x
      end

      struct Foo
        def initialize
          @value = 1
        end

        def value
          bar(@value)
          @value
        end
      end

      def get_proc_a
        foo = Foo.new
        ->foo.value
      end

      def get_proc_b
        foo = Foo.new
        ->{ foo.value }
      end

      proc_a = get_proc_a
      proc_b = get_proc_b
      proc_b.call
      proc_a.call
      )).to_i.should eq(1)
  end

  it "saves receiver value of proc pointer `->var.foo`" do
    run(%(
      class Foo
        def initialize(@foo : Int32)
        end

        def foo
          @foo
        end
      end

      var = Foo.new(1)
      proc = ->var.foo
      var = Foo.new(2)
      proc.call
      )).to_i.should eq(1)
  end

  it "saves receiver value of proc pointer `->@ivar.foo`" do
    run(%(
      class Foo
        def initialize(@foo : Int32)
        end

        def foo
          @foo
        end
      end

      class Test
        @ivar = Foo.new(1)

        def test
          proc = ->@ivar.foo
          @ivar = Foo.new(2)
          proc.call
        end
      end

      Test.new.test
      )).to_i.should eq(1)
  end

  it "saves receiver value of proc pointer `->@@cvar.foo`" do
    run(%(
      require "prelude"

      class Foo
        def initialize(@foo : Int32)
        end

        def foo
          @foo
        end
      end

      class Test
        @@cvar = Foo.new(1)

        def self.test
          proc = ->@@cvar.foo
          @@cvar = Foo.new(2)
          proc.call
        end
      end

      Test.test
      )).to_i.should eq(1)
  end

  # FIXME: JIT compilation of this spec is broken, forcing normal compilation (#10961)
  it "doesn't crash when taking a proc pointer to a virtual type (#9823)" do
    run(%(
      abstract struct Parent
        abstract def work(a : Int32, b : Int32)

        def get
          ->work(Int32, Int32)
        end
      end

      struct Child1 < Parent
        def work(a : Int32, b : Int32)
          a &+ b
        end
      end

      struct Child2 < Parent
        def work(a : Int32, b : Int32)
          a &- b
        end
      end

      Child1.new.as(Parent).get
    ), flags: [] of String)
  end

  it "doesn't crash when taking a proc pointer that multidispatches on the top-level (#3822)" do
    run(%(
      class Foo
        def initialize(@proc : Proc(Bar, Nil))
        end
      end

      module Bar
      end

      class Baz
        include Bar
      end

      def test(bar : Bar)
        if bar.is_a? Baz
          test bar
        end
      end

      def test(baz : Baz)
      end

      Foo.new(->test(Bar))
    ))
  end

  it "doesn't crash when taking a proc pointer that multidispatches on a module (#3822)" do
    run(%(
      class Foo
        def initialize(@proc : Proc(Bar, Nil))
        end
      end

      module Bar
      end

      class Baz
        include Bar
      end

      module Moo
        def self.test(bar : Bar)
          if bar.is_a? Baz
            test bar
          end
        end

        def self.test(baz : Baz)
        end
      end

      Foo.new(->Moo.test(Bar))
    ))
  end
end
