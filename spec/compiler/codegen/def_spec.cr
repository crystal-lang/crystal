require "../../spec_helper"

describe "Code gen: def" do
  it "codegens empty def" do
    run("def foo; end; foo")
  end

  it "codegens call without args" do
    run("def foo; 1; end; 2; foo").to_i.should eq(1)
  end

  it "call functions defined in any order" do
    run("def foo; bar; end; def bar; 1; end; foo").to_i.should eq(1)
  end

  it "codegens call with args" do
    run("def foo(x); x; end; foo 1").to_i.should eq(1)
  end

  it "call external function 'putchar'" do
    run("
      lib LibC
        fun putchar(c : Char) : Char
      end
      LibC.putchar '\\0'
      ").to_i.should eq(0)
  end

  it "uses self" do
    run("struct Int; def foo; self &+ 1; end; end; 3.foo").to_i.should eq(4)
  end

  it "uses var after external" do
    run("
      lib LibC
        fun putchar(c : Char) : Char
      end

      a = 1
      LibC.putchar '\\0'
      a
      ").to_i.should eq(1)
  end

  it "allows to change argument values" do
    run("def foo(x); x = 1; x; end; foo(2)").to_i.should eq(1)
  end

  it "runs empty def" do
    run("def foo; end; foo")
  end

  it "builds infinite recursive function" do
    codegen "def foo; foo; end; foo"
  end

  it "unifies all calls to same def" do
    run("
      require \"prelude\"

      def raise(msg)
        nil
      end

      class Hash2
        def initialize
          @buckets = [[1]]
        end

        def []=(key, value)
          bucket.push value
        end

        def [](key)
          bucket[0]
        end

        def bucket
          @buckets[0]
        end
      end

      hash = Hash2.new
      hash[1] = 2
      hash[1]
    ").to_i.should eq(1)
  end

  it "codegens recursive type with union" do
    run("
      class Foo
        @next : Foo?

        def next=(n)
          @next = n
        end

        def next
          @next
        end
      end

      a = Foo.allocate
      a.next = Foo.allocate
      a = a.next
      ")
  end

  it "codegens with related types" do
    run("
      class Foo
        @next : Foo | Bar | Nil

        def next=(n)
          @next = n
        end

        def next
          @next
        end
      end

      class Bar
        @next : Foo | Bar | Nil

        def next=(n)
          @next = n
        end

        def next
          @next
        end
      end

      def foo(x, y)
        if n = x.next
          n.next = y
        end
      end

      a = Foo.allocate
      a.next = Bar.allocate

      foo(a, Bar.allocate)

      c = Foo.allocate
      c.next = Bar.allocate

      foo(c, c.next)
      ")
  end

  it "codegens and doesn't break if obj is int and there's a mutation" do
    run("
      require \"prelude\"

      struct Int
        def baz(x)
        end
      end

      elems = [1]
      elems[0].baz [1]
    ")
  end

  it "codegens with and without default arguments" do
    run("
      def foo(x = 1)
        x &+ 1
      end

      foo(2) &+ foo
      ").to_i.should eq(5)
  end

  it "codegens with and without many default arguments" do
    run("
      def foo(x = 1, y = 2, z = 3)
        x &+ y &+ z
      end

      foo &+ foo(9) &+ foo(3, 4) &+ foo(6, 3, 1)
      ").to_i.should eq(40)
  end

  it "codegens with interesting default argument" do
    run("
      class Foo
        def foo(x = self.bar)
          x &+ 1
        end

        def bar
          1
        end
      end

      f = Foo.new

      f.foo(2) &+ f.foo
      ").to_i.should eq(5)
  end

  it "codegens dispatch on static method" do
    run("
      def Object.foo(x)
        1
      end

      a = 1
      a = 1.5
      Object.foo(a)
      ").to_i.should eq(1)
  end

  it "use target def type as return type" do
    run("
      require \"prelude\"

      def foo
        if false
          return 0
        end
      end

      foo.nil? ? 1 : 0
    ").to_i.should eq(1)
  end

  it "codegens recursive nasty code" do
    codegen("
      class Foo
        def initialize(x)
        end
      end

      class Bar
        def initialize(x)
        end
      end

      class Box
        @elem : Foo | Bar | Nil

        def set(elem)
          @elem = elem
        end

        def get
          @elem
        end
      end

      def foo
        exps = Box.new
        sub = foo
        t = Foo.new(sub) || Bar.new(sub)
        exps.set t
        exps.get || 1
      end

      false && foo
      ")
  end

  it "looks up matches in super classes and merges them with subclasses" do
    run("
      class Foo
        def foo(other)
          1
        end
      end

      class Bar < Foo
        def foo(other : Int)
          2
        end
      end

      bar1 = Bar.new
      bar1.foo(1 || 1.5)
      ").to_i.should eq(2)
  end

  it "codegens def which changes type of arg" do
    run("
      def foo(x)
        while x >= 0
          x = -0.5
        end
        x
      end

      foo(2).to_i!
    ").to_i.should eq(0)
  end

  it "codegens return nil when nilable type (1)" do
    run("
      def foo
        return if 1 == 1
        Reference.new
      end

      foo.nil?
      ").to_b.should be_true
  end

  it "codegens return nil when nilable type (2)" do
    run("
      def foo
        return nil if 1 == 1
        Reference.new
      end

      foo.nil?
      ").to_b.should be_true
  end

  it "codegens dispatch with nilable reference union type" do
    run("
      struct Nil; def object_id; 0_u64; end; end
      class Foo; end
      class Bar; end

      f = 1 == 1 ? nil : (Foo.new || Bar.new)
      f.object_id
      ").to_i.should eq(0)
  end

  it "codegens dispatch without obj, bug 1" do
    run("
      def coco(x : Int32)
        2
      end

      def coco(x)
        3
      end

      class Foo
        def foo
          coco(1 || nil)
        end
      end

      Foo.new.foo
      ").to_i.should eq(2)
  end

  it "codegens dispatch without obj, bug 1" do
    run("
      def coco(x : Int32)
        2
      end

      def coco(x)
        3
      end

      class Foo
        def foo
          coco(1 || nil)
        end
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).foo
      ").to_i.should eq(2)
  end

  it "codegens dispatch with single def when discarding unallocated ones (1)" do
    run("
      class Foo
        def bar
          1
        end
      end

      class Bar
        def bar
          2
        end
      end

      foo = 1 == 1 ? Foo.new : Pointer(Int32).new(0_u64).as(Bar)
      foo.bar
      ").to_i.should eq(1)
  end

  it "codegens dispatch with single def when discarding unallocated ones (2)" do
    run("
      class Foo
      end

      class Bar
      end

      def something(x : Foo)
        1
      end

      def something(x : Bar)
        2
      end

      foo = 1 == 1 ? Foo.new : Pointer(Int32).new(0_u64).as(Bar)
      something(foo)
      ").to_i.should eq(1)
  end

  it "codegens bug #119" do
    run(%(
      require "prelude"

      x = {} of String => Hash(String, String)
      x.has_key?("a")
      )).to_b.should be_false
  end

  it "puts union before single type in matches preferences" do
    run("
      abstract class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      def foo(x : Foo)
        2
      end

      def foo(x : Bar | Baz)
        1
      end

      node = Baz.new || Bar.new
      foo(node)
      ").to_i.should eq(1)
  end

  it "dispatches on virtual type implementing generic module (related to bug #165)" do
    run("
      module Moo(T)
        def moo
          1
        end
      end

      abstract class Foo
      end

      class Bar < Foo
        include Moo(Int32)
      end

      class Baz < Foo
      end

      def method(x : Moo(Int32))
        x.moo
      end

      def method(x : Baz)
        2
      end

      foo = Bar.new || Baz.new
      method(foo)
      ").to_i.should eq(1)
  end

  it "fixes #230: include original owner in mangled def" do
    run(%(
      class Base
        def some(other : self)
          false
        end

        def some(other)
          false
        end
      end

      class Foo(T) < Base
        def some(other : Foo)
          true
        end
      end

      a = Foo(Int32).new
      b = Foo(Int32).new || Foo(Int32 | Nil).new || true
      a.some(b)

      c = Foo(Int32).new
      c.some(c)
      )).to_b.should be_true
  end

  it "doesn't crash on private def as last expression" do
    codegen(%(
      private def foo
      end
      ))
  end

  it "uses previous argument in default value (#1062)" do
    run(%(
      def foo(x = 123, y = x &+ 456)
        x &+ y
      end

      foo
      )).to_i.should eq(123 * 2 + 456)
  end

  it "can match N type argument of static array (#1203)" do
    run(%(
      def fn(a : StaticArray(T, N)) forall T, N
        N
      end

      n = uninitialized StaticArray(Int32, 10)
      fn(n)
      )).to_i.should eq(10)
  end

  it "uses dispatch call type for phi (#3529)" do
    codegen(%(
      def foo(x : Int32)
        yield
        1.0
      end

      def foo(x : Int64)
        yield
        1.0
      end

      foo(1 || 1_i64) do
        break
      end
      ), inject_primitives: false)
  end

  it "codegens union to union assignment of mutable arg (#3691)" do
    codegen(%(
      def foo(arg)
        arg = ""
      end

      foo(1 || true)
      ))
  end

  it "codegens yield with destructing tuple having unreachable element" do
    codegen(%(
      def foo
        yield({1, while true; end})
      end

      foo { |a, b| }
      ))
  end
end
