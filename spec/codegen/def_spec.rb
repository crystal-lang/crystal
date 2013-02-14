require 'spec_helper'

describe 'Code gen: def' do
  it "codegens empty def" do
    run('def foo; end; foo')
  end

  it "codegens call without args" do
    run('def foo; 1; end; 2; foo').to_i.should eq(1)
  end

  it "call functions defined in any order" do
    run('def foo; bar; end; def bar; 1; end; foo').to_i.should eq(1)
  end

  it "codegens call with args" do
    run('def foo(x); x; end; foo 1').to_i.should eq(1)
  end

  it "call external function 'putchar'" do
    run(%q(require "io"; C.putchar '\\0')).to_i.should eq(0)
  end

  it "uses self" do
    run("class Int; def foo; self + 1; end; end; 3.foo").to_i.should eq(4)
  end

  it "uses var after external" do
    run(%q(require "io"; a = 1; C.putchar '\\0'; a)).to_i.should eq(1)
  end

  it "allows to change argument values" do
    run("def foo(x); x = 1; x; end; foo(2)").to_i.should eq(1)
  end

  it "runs empty def" do
    run("def foo; end; foo")
  end

  it "builds infinite recursive function" do
    node = parse "def foo; foo; end; foo"
    mod = infer_type node
    build node, mod
  end

  it "includes return type in the mangled name" do
    run(%Q(
      generic class Foo
        #{rw :value}
      end

      def gen
        Foo.new
      end

      f = gen
      f.value = 1

      g = gen
      g.value = 2.5f

      f.value + g.value
    )).to_f.should eq(3.5)
  end

  it "unifies all calls to same def" do
    run(%Q(
      require "pointer"
      require "array"

      class Hash
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

      hash = Hash.new
      hash[1] = 2
      hash[1]
    )).to_i.should eq(1)
  end

  it "mutates to union" do
    run(%Q(
      require "pointer"
      require "array"

      class Foo
        def foo(x)
          @buckets = [x]
        end

        def bar
          @buckets.push 1
        end
      end

      f = Foo.new
      f.foo(1)
      f.bar
      f.foo(1.5f)[0].to_f
      )).to_f.should eq(1.5)
  end

  it "mutates to union 2" do
    run(%Q(
      require "pointer"
      require "array"

      class Foo
        def foo(x)
          @buckets = [x]
        end

        def bar
          @buckets.push 1
        end
      end

      f = Foo.new
      f.foo(1)
      f.bar
      f.foo(1.5)
      f.foo(1)[0].to_f
      )).to_f.should eq(1)
  end

  it "codegens recursive type with union" do
    run(%Q(
      class A
       def next=(n)
         @next = n
       end

       def next
         @next
       end
      end

      a = A.alloc
      a.next = A.alloc
      a = a.next
      ))
  end

  it "codegens with related types" do
    run(%Q(
      class A
       def next=(n)
         @next = n
       end

       def next
         @next
       end
      end

      class B
       def next=(n)
         @next = n
       end

       def next
         @next
       end
      end

      def foo(x, y)
        x.next.next = y
      end

      a = A.alloc
      a.next = B.alloc

      foo(a, B.alloc)

      c = A.alloc
      c.next = B.alloc

      foo(c, c.next)
      ))
  end

  it "codegens and doesn't break if obj is int and there's a mutation" do
    run(%Q(
      require "pointer"
      require "array"

      class Int
        def baz(x)
        end
      end

      elems = [1]
      elems[0].baz [1]
    ))
  end

  it "codegens with and witout default arguments" do
    run(%Q(
      def foo(x = 1)
        x + 1
      end

      foo(2) + foo
      )).to_i.should eq(5)
  end

  it "codegens with interesting default argument" do
    run(%Q(
      class Foo
        def foo(x = self.bar)
          x + 1
        end

        def bar
          1
        end
      end

      f = Foo.new

      f.foo(2) + f.foo
      )).to_i.should eq(5)
  end

  it "codegens dispatch on static method" do
    run(%Q(
      def Object.foo(x)
        1
      end

      a = 1
      a = 1.5
      Object.foo(a)
      )).to_i.should eq(1)
  end

  it "use target def type as return type" do
    run(%Q(
      require "nil"
      require "object"

      def foo
        if false
          return 0
        end
      end

      foo.nil? ? 1 : 0
    )).to_i.should eq(1)
  end

  it "codegens recursive nasty code" do
    run(%Q(
      require "prelude"
      class Foo
        def initialize(x)
        end
      end

      class Bar
        def initialize(x)
        end
      end

      def fun
        exps = []
        sub = fun
        t = Foo.new(sub) || Bar.new(sub)
        exps.push t
        exps[0] || 1
      end

      fun
      ))
  end
end