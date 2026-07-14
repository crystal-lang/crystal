require "../../spec_helper"

describe "Code gen: block" do
  it "generate inline" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
      end

      foo do
        1
      end
      CRYSTAL
  end

  it "passes yield arguments" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        yield 1
      end

      foo do |x|
        x &+ 1
      end
      CRYSTAL
  end

  it "pass arguments to yielder function" do
    run(<<-CRYSTAL).to_i.should eq(4)
      def foo(a)
        yield a
      end

      foo(3) do |x|
        x &+ 1
      end
      CRYSTAL
  end

  it "pass self to yielder function" do
    run(<<-CRYSTAL).to_i.should eq(4)
      struct Int
        def foo
          yield self
        end
      end

      3.foo do |x|
        x &+ 1
      end
      CRYSTAL
  end

  it "pass self and arguments to yielder function" do
    run(<<-CRYSTAL).to_i.should eq(5)
      struct Int
        def foo(i)
          yield self, i
        end
      end

      3.foo(2) do |x, i|
        x &+ i
      end
      CRYSTAL
  end

  it "allows access to local variables" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        yield
      end

      x = 1
      foo do
        x &+ 1
      end
      CRYSTAL
  end

  it "can access instance vars from yielder function" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        def initialize
          @x = 1
        end
        def foo
          yield @x
        end
      end

      Foo.new.foo do |x|
        x &+ 1
      end
      CRYSTAL
  end

  it "can set instance vars from yielder function" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        def initialize
          @x = 1
        end

        def foo
          @x = yield
        end
        def value
          @x
        end
      end

      a = Foo.new
      a.foo { 2 }
      a.value
      CRYSTAL
  end

  it "can use instance methods from yielder function" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        def foo
          yield value
        end
        def value
          1
        end
      end

      Foo.new.foo { |x| x &+ 1 }
      CRYSTAL
  end

  it "can call methods from block when yielder is an instance method" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo
          yield
        end
      end

      def bar
        1
      end

      Foo.new.foo { bar }
      CRYSTAL
  end

  it "nested yields" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def bar
        yield
      end

      def foo
        bar { yield }
      end

      a = foo { 1 }
      CRYSTAL
  end

  it "assigns yield to argument" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo(x)
        yield
        x = 1
      end

      foo(1) { 1 }
      CRYSTAL
  end

  it "can use global constant" do
    run(<<-CRYSTAL).to_i.should eq(1)
      FOO = 1
      def foo
        yield
        FOO
      end
      foo { }
      CRYSTAL
  end

  it "return from yielder function" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        yield
        return 1
      end

      foo { }
      2
      CRYSTAL
  end

  it "return from block" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
      end

      def bar
        foo { return 1 }
        2
      end

      bar
      CRYSTAL
  end

  it "return from yielder function (2)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
        return 1 if true
        return 2
      end

      def bar
        foo {}
      end

      bar
      CRYSTAL
  end

  it "union value of yielder function" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
        a = 1.1
        a = 1
        a
      end

      foo {}.to_i!
      CRYSTAL
  end

  it "allow return from function called from yielder function" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        return 2
      end

      def bar
        yield
        foo
        1
      end

      bar {}
      CRYSTAL
  end

  it "" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
        true ? return 1 : return 1.1
      end

      foo {}.to_i!
      CRYSTAL
  end

  it "return from block that always returns from function that always yields inside if block" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def bar
        yield
        2
      end

      def foo
        if true
          bar { return 1 }
        else
          0
        end
      end

      foo
      CRYSTAL
  end

  it "return from block that always returns from function that conditionally yields" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def bar
        if true
          yield
        end
      end

      def foo
        bar { return 1 }
        2
      end

      foo
      CRYSTAL
  end

  it "call block from dispatch" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def bar(y)
        yield y
      end

      def foo
        x = 1.1
        x = 1
        bar(x) { |z| z }
      end

      foo.to_i!
      CRYSTAL
  end

  it "call block from dispatch and use local vars" do
    run(<<-CRYSTAL).to_i.should eq(4)
      require "prelude"

      def bar(y)
        yield y
      end

      def foo
        total = 0
        x = 1.5
        bar(x) { |z| total += z }
        x = 1
        bar(x) { |z| total += z }
        x = 1.5
        bar(x) { |z| total += z }
        total
      end

      foo.to_i
      CRYSTAL
  end

  it "break without value returns nil" do
    run(<<-CRYSTAL).to_b.should be_true
      require "nil"
      require "value"

      def foo
        yield
        1
      end

      x = foo do
        break if 1 == 1
      end

      x.nil?
      CRYSTAL
  end

  it "break block with yielder inside while" do
    run(<<-CRYSTAL).to_i.should eq(6)
      require "prelude"
      a = 0
      10.times do
        a += 1
        break if a > 5
      end
      a
      CRYSTAL
  end

  it "break from block returns from yielder" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
        yield
      end

      a = 0
      foo { a &+= 1; break }
      a
      CRYSTAL
  end

  it "break from block with value" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        while true
          yield
          a = 3
        end
      end

      foo do
        break 1
      end
      CRYSTAL
  end

  it "returns from block with value" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      def foo
        while true
          yield
          a = 3
        end
      end

      def bar
        foo do
          return 1
        end
      end

      bar.to_i
      CRYSTAL
  end

  it "doesn't codegen after while that always yields and breaks" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        while true
          yield
        end
        1
      end

      foo do
        break 2
      end
      CRYSTAL
  end

  it "break from block with value" do
    run(<<-CRYSTAL).to_i.should eq(20)
      require "prelude"
      10.times { break 20 }
      CRYSTAL
  end

  it "doesn't codegen call if arg yields and always breaks" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "nil"

      def foo
        1 &+ yield
      end

      foo { break 2 }.to_i!
      CRYSTAL
  end

  it "codegens nested return" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def bar
        yield
        a = 1
      end

      def foo
        bar { yield }
      end

      def z
        foo { return 2 }
      end

      z
      CRYSTAL
  end

  it "codegens nested break" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def bar
        yield
        a = 1
      end

      def foo
        bar { yield }
      end

      foo { break 2 }
      CRYSTAL
  end

  it "codegens call with block with call with arg that yields" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def bar
        yield
        a = 2
      end

      def foo
        bar { 1 &+ yield }
      end

      foo { break 3 }
      CRYSTAL
  end

  it "can break without value from yielder that returns nilable (1)" do
    run(<<-CRYSTAL).to_b.should be_true
      def foo
        yield
        ""
      end

      a = foo do
        break
      end

      a.nil?
      CRYSTAL
  end

  it "can break without value from yielder that returns nilable (2)" do
    run(<<-CRYSTAL).to_b.should be_true
      def foo
        yield
        ""
      end

      a = foo do
        break nil
      end

      a.nil?
      CRYSTAL
  end

  it "break with value from yielder that returns a nilable" do
    run(<<-CRYSTAL).to_b.should be_false
      def foo
        yield
        ""
      end

      a = foo do
        break if false
        break ""
      end

      a.nil?
      CRYSTAL
  end

  it "can use self inside a block called from dispatch" do
    run(<<-CRYSTAL).to_i.should eq(123)
      struct Nil; def to_i!; 0; end; end

      class Foo
        def do; yield; end
      end
      class Bar < Foo
      end

      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      struct Int
        def foo
          x = Foo.new
          x = Bar.new
          x.do { Global.x = self }
        end
      end

      123.foo
      Global.x.to_i!
      CRYSTAL
  end

  it "return from block called from dispatch" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def do; yield; end
      end
      class Bar < Foo
      end

      def foo
        x = Foo.new
        x = Bar.new
        x.do { return 1 }
        0
      end

      foo
      CRYSTAL
  end

  it "breaks from while in function called from block" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        yield
      end

      def bar
        while true
          break 1
        end
        2
      end

      foo do
        bar
      end
      CRYSTAL
  end

  it "allows modifying yielded value (with literal)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        yield 1
      end

      foo { |x| x = 2; x }
      CRYSTAL
  end

  it "allows modifying yielded value (with variable)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        a = 1
        yield a
        a
      end

      foo { |x| x = 2; x }
      CRYSTAL
  end

  it "it yields nil from another call" do
    run(<<-CRYSTAL)
      require "bool"

      def foo(key, default)
        foo(key) { default }
      end

      def foo(key)
        if !(true)
          return yield key
        end
        yield key
      end

      foo(1, nil)
      CRYSTAL
  end

  it "allows yield from dispatch call" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo(x : Value)
        yield 1
      end

      def foo(x : Int)
        yield 2
      end

      def bar
        a = 1; a = 1.1
        foo(a) do |i|
          yield i
        end
      end

      x = 0
      bar { |i| x = i }
      x
      CRYSTAL
  end

  it "block with nilable type" do
    run(<<-CRYSTAL)
      class Foo
        def foo
          yield 1
        end
      end

      class Bar
        def foo
          yield 2
          Reference.new
        end
      end

      a = Foo.new || Bar.new
      a.foo {}
      CRYSTAL
  end

  it "block with nilable type 2" do
    run(<<-CRYSTAL)
      class Foo
        def foo
          yield 1
          nil
        end
      end

      class Bar
        def foo
          yield 2
          Reference.new
        end
      end

      a = Foo.new || Bar.new
      a.foo {}
      CRYSTAL
  end

  it "codegens block with nilable type with return (1)" do
    run(<<-CRYSTAL).to_b.should be_true
      def foo
        if yield
          return Reference.new
        end
        nil
      end

      foo { false }.nil?
      CRYSTAL
  end

  it "codegens block with nilable type with return (2)" do
    run(<<-CRYSTAL).to_b.should be_false
      def foo
        if yield
          return nil
        end
        Reference.new
      end

      foo { false }.nil?
      CRYSTAL
  end

  it "codegens block with union with return" do
    run(<<-CRYSTAL)
      def foo
        yield

        return 1 if 1 == 2

        nil
      end

      x = foo { }
      1
      CRYSTAL
  end

  it "codegens if with call with block (ssa issue)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def bar
        yield
      end

      def foo
        if 1 == 2
          bar do
            x = 1
          end
        else
          3
        end
      end

      foo
      CRYSTAL
  end

  it "codegens block with return and yield and no return" do
    run(<<-CRYSTAL).to_i.should eq(2)
      lib LibC
        fun exit : NoReturn
      end

      def foo(key)
        foo(key) { LibC.exit }
      end

      def foo(key)
        if 1 == 1
          return 2
        end
        yield
      end

      foo 1
      CRYSTAL
  end

  it "codegens while/break inside block" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
      end

      foo do
        while true
          break
        end
        1
      end
      CRYSTAL
  end

  it "codegens block with union arg (1)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield 1 || 1.5
      end

      foo { |x| x }.to_i!
      CRYSTAL
  end

  it "codegens block with union arg (2)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      struct Number
        def abs
          self
        end
      end

      class Foo(T)
        def initialize(x : T)
          @x = x
        end

        def each
          yield @x
        end
      end

      a = Foo.new(1) || Foo.new(1.5)
      a.each do |x|
        x.abs
      end.to_i!
      CRYSTAL
  end

  it "codegens block with virtual type arg" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Var(T)
        def initialize(x : T)
          @x = x
        end

        def each
          yield @x
        end
      end

      class Foo
        def bar
          1
        end
      end

      class Bar < Foo
        def bar
          2
        end
      end

      a = Var.new(Foo.new) || Var.new(Bar.new)
      a.each do |x|
        x.bar
      end
      CRYSTAL
  end

  it "codegens call with blocks of different type without args" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield
      end

      foo { 1.1 }
      foo { 1 }
      CRYSTAL
  end

  it "codegens dispatch with block and break (1)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      class Foo(T)
        def initialize(@x : T)
        end

        def each
          yield @x
        end
      end

      n = 0
      f = Foo.new(1) || Foo.new(1.5)
      f.each do |x|
        break if x > 2
        n += x
      end
      n.to_i
      CRYSTAL
  end

  it "codegens dispatch with block and break (2)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "prelude"

      a = [1, 2, 3] || [1.5]
      n = 0
      a.each do |x|
        break if x > 2
        n += x
      end
      n.to_i
      CRYSTAL
  end

  it "codegens block call when argument type changes" do
    run(<<-CRYSTAL)
      def foo(x)
        while 1 == 2
          x = 1.5
          yield
        end
      end

      foo(1) do
      end
      CRYSTAL
  end

  it "returns void when called with block" do
    run(<<-CRYSTAL)
      fun foo : Void
      end

      def bar
        yield
        foo
      end

      bar {}
      CRYSTAL
  end

  it "executes yield expression if no arg is given for block" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        a = 1
        yield (a = 2)
        a
      end

      foo { }
      CRYSTAL
  end

  it "codegens bug with block and arg and var" do
    run(<<-CRYSTAL).to_i.should eq(65)
      def foo
        yield 1
      end

      foo { |a| x = a }

      foo do
        a = 'A'
        a.ord
      end
      CRYSTAL
  end

  it "allows using var as block arg with outer var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield 'a'
      end

      a = foo do |a|
        1
      end
      CRYSTAL
  end

  it "allows initialize with yield (#224)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        @x : Int32

        def initialize
          @x = yield 1
        end

        def x
          @x
        end
      end

      foo = Foo.new do |a|
        a &+ 1
      end
      foo.x
      CRYSTAL
  end

  it "uses block inside array literal (bug)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      def foo
        yield 1
      end

      ary = [foo { |x| x.abs }]
      ary[0]
      CRYSTAL
  end

  it "codegens method invocation on a object of a captured block with a type that was never instantiated" do
    codegen(<<-CRYSTAL)
      class Bar
        def initialize(@bar : NoReturn)
        end

        def bar
          @bar
        end

        def baz(x)
        end
      end

      def foo(&block : Bar ->)
        block
      end

      def method(bar)
        bar.bar
      end

      foo do |bar|
        bar.baz method(bar).baz
      end
      CRYSTAL
  end

  it "codegens method invocation on a object of a captured block with a type that was never instantiated (2)" do
    codegen(<<-CRYSTAL)
      class Bar
        def initialize(@bar : NoReturn)
        end

        def bar
          @bar
        end
      end

      def foo(&block : Bar ->)
        block
      end

      def method(bar)
        bar.bar
      end

      def baz(x)
      end

      foo do |bar|
        baz method(bar).baz
      end
      CRYSTAL
  end

  it "codegens bug with yield not_nil! that is never not nil" do
    run(<<-CRYSTAL).to_i.should eq(1)
      lib LibC
        fun exit(Int32) : NoReturn
      end

      class Object
        def not_nil!
          self
        end
      end

      struct Nil
        def not_nil!
          LibC.exit(1)
        end

        def to_i!
          0
        end
      end

      def foo
        key = nil
        if 1 == 2
          yield key.not_nil!
        end
        yield 1
      end

      extra = nil

      foo do |key|
        if 1 == 1
          extra = 1
          extra &+ key
        end
      end

      extra.to_i!
      CRYSTAL
  end

  it "uses block var with same name as local var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield "hello"
      end

      a = 1
      foo do |a|
        a
      end
      a
      CRYSTAL
  end

  it "doesn't crash on untyped array to_s" do
    run(<<-CRYSTAL).to_string.should eq("[]")
      require "prelude"

      class Bar(T)
      end

      class Foo(K)
        @foo : Nil

        def foo
          Array(typeof(yield @foo.not_nil!)).new
        end
      end

      Foo(Int32).new.foo { |k| k + 1 }.to_s
      CRYSTAL
  end

  it "codegens block which always breaks but never enters (#494)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def foo
        while 1 == 2
          yield
        end
        3
      end

      foo do
        break 10
      end
      CRYSTAL
  end

  it "codegens block bug with conditional next and unconditional break (1)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      def foo
        yield 1
        yield 2
        yield 3
      end

      a = 0
      foo do |x|
        a &+= x
        next if true
        break
      end
      a
      CRYSTAL
  end

  it "codegens block bug with conditional next and unconditional break (2)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      def foo
        yield 1
        yield 2
        yield 3
      end

      a = 0
      foo do |x|
        a &+= x
        next if 1 == 1
        break
      end
      a
      CRYSTAL
  end

  it "codegens block bug with conditional next and unconditional break (3)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        a = 1234
        a = yield 1
        Global.x = a
        a
      end

      foo do |x|
        next x if 1 == 1
        break 0
      end
      Global.x
      CRYSTAL
  end

  it "codegens block bug with conditional next and unconditional break (4)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        bar(yield 1)
      end

      def bar(x)
        Global.x = x
      end

      foo do |x|
        next x if 1 == 1
        break 0
      end
      Global.x
      CRYSTAL
  end

  it "returns from proc literal" do
    run(<<-CRYSTAL).to_i.should eq(10)
      foo = ->{
        if 1 == 1
          return 10
        end

        20
      }

      foo.call
      CRYSTAL
  end

  it "does next from captured block" do
    run(<<-CRYSTAL).to_i.should eq(10)
      def foo(&block : -> T) forall T
        block
      end

      f = foo do
        if 1 == 1
          next 10
        end

        next 20
      end

      f.call
      CRYSTAL
  end

  it "codegens captured block with next inside yielded block (#2097)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      def foo
        yield
      end

      def bar(&block : -> Int32)
        block
      end

      foo do
        block = bar do
          next 123
        end
        block.call
      end
      CRYSTAL
  end

  it "codegens captured block that returns union, but proc only returns a single type" do
    run(<<-CRYSTAL).to_string.should eq("foo")
      def run_callbacks(&block : -> Int32 | String)
        block.call
      end

      f = run_callbacks { "foo" }
      if f.is_a?(String)
        f
      else
        "oops"
      end
      CRYSTAL
  end

  it "yields inside yield (#682)" do
    run(<<-CRYSTAL).to_i.should eq(4)
      def foo
        yield(1, (yield 3))
      end

      a = 0
      foo do |x|
        a &+= x
      end
      a
      CRYSTAL
  end

  it "yields splat" do
    run(<<-CRYSTAL).to_i.should eq(6)
      def foo
        tup = {1, 2, 3}
        yield *tup
      end

      foo do |x, y, z|
        x &+ y &+ z
      end
      CRYSTAL
  end

  it "yields more exps than block arg, through splat" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        yield *{1, 2}
      end

      foo do |x|
        x
      end
      CRYSTAL
  end

  it "uses splat in block argument" do
    run(<<-CRYSTAL).to_i.should eq(6)
      def foo
        yield 1, 2, 3
      end

      foo do |*args|
        args[0] &+ args[1] &+ args[2]
      end
      CRYSTAL
  end

  it "uses splat in block argument, many args" do
    run(<<-CRYSTAL).to_i.should eq(((((1 + 2) * 3) - 4) * 5) - 6)
      def foo
        yield 1, 2, 3, 4, 5, 6
      end

      foo do |x, y, *z, w|
        ((((x &+ y) &* z[0]) &- z[1]) &* z[2]) &- w
      end
      CRYSTAL
  end

  it "uses block splat argument with union types" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def foo
        yield 1
        yield 2.5
      end

      total = 0
      foo do |*args|
        total &+= args[0].to_i!
      end
      total
      CRYSTAL
  end

  it "works if block has both splat and non-splat underscore parameters" do
    run(<<-CRYSTAL, Int32).should eq(34)
      def foo(&)
        yield 1, 2, 4, 8, 16, 32
      end

      foo do |_, a, *_, b|
        a &+ b
      end
      CRYSTAL
  end

  it "works if block has both splat parameter and multiple non-splat underscore parameters" do
    run(<<-CRYSTAL, Int32).should eq(40)
      def foo(&)
        yield 1, 2, 4, 8, "", 32
      end

      foo do |_, *a, _, b|
         a[2] &+ b
      end
      CRYSTAL
  end

  it "auto-unpacks tuple" do
    run(<<-CRYSTAL).to_i.should eq((1 + 2) * 4)
      def foo
        tup = {1, 2, 4}
        yield tup
      end

      foo do |x, y, z|
        (x &+ y) &* z
      end
      CRYSTAL
  end

  it "unpacks tuple but doesn't override local variables" do
    run(<<-CRYSTAL).to_i.should eq(10)
      def foo
        yield({10, 20}, {30, 40})
      end

      x = 1
      y = 2
      z = 3
      w = 4
      foo do |(x, y), (z, w)|
      end
      x &+ y &+ z &+ w
      CRYSTAL
  end

  it "codegens block with multiple underscores (#3054)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def foo(&block : Int32, Int32 -> Int32)
        block.call(1, 2)
      end

      foo do |_, _|
        3
      end
      CRYSTAL
  end

  it "breaks in var assignment (#3364)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      def foo
        yield
        456
      end

      foo do
        a = nil || break 123
      end
      CRYSTAL
  end

  it "nexts in var assignment (#3364)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      def foo
        yield
      end

      foo do
        a = nil || next 123
      end
      CRYSTAL
  end

  it "dispatches with captured and non-captured block (#3969)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def fn(x : Int32, &block)
        x
      end

      def fn(x : Char, &block : -> Int32)
        block.call
      end

      a = fn(1 || 'a') { 2 }
      b = fn('a' || 1) { 2 }
      a &+ b
      CRYSTAL
  end

  it "codegens block with repeated underscore and different types (#4711)" do
    codegen(<<-CRYSTAL)
      def foo
        yield('0', 0)
      end
      foo{|_, _| }
      CRYSTAL
  end

  it "doesn't crash on yield exp without a type (#8100)" do
    codegen(<<-CRYSTAL)
      def foo
        x = 1
        if x.is_a?(Char)
          yield x
        else
          yield x
        end
      end

      foo { |x| }
      CRYSTAL
  end

  it "clears nilable var before inlining block method (#10087)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @@x = 0

        def self.bar
          i = 0
          while i < 2
            yield i
            i &+= 1
          end
          @@x
        end

        def self.foo(x)
          if x == 0
            bug = "Hello"
          end

          if bug
            @@x &+= 1
          end

          yield
        end

      end

      Foo.bar do |z|
        Foo.foo(z) { }
      end
      CRYSTAL
  end

  it "(bug) doesn't set needs_value to true on every yield (#12442)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo
        if true
          yield
        end

        1
      end

      foo do
        1
      end
      CRYSTAL
  end

  it "doesn't crash if yield exp has no type (#12670)" do
    codegen(<<-CRYSTAL)
      def foo : String?
      end

      def bar
        while res = foo
          yield res
        end
      end

      bar do |res|
        res
      end
      CRYSTAL
  end
end
