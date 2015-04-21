require "../../spec_helper"

describe "Code gen: block" do
  it "generate inline" do
    expect(run("
      def foo
        yield
      end

      foo do
        1
      end
    ").to_i).to eq(1)
  end

  it "passes yield arguments" do
    expect(run("
      def foo
        yield 1
      end

      foo do |x|
        x + 1
      end
    ").to_i).to eq(2)
  end

  it "pass arguments to yielder function" do
    expect(run("
      def foo(a)
        yield a
      end

      foo(3) do |x|
        x + 1
      end
    ").to_i).to eq(4)
  end

  it "pass self to yielder function" do
    expect(run("
      struct Int
        def foo
          yield self
        end
      end

      3.foo do |x|
        x + 1
      end
    ").to_i).to eq(4)
  end

  it "pass self and arguments to yielder function" do
    expect(run("
      struct Int
        def foo(i)
          yield self, i
        end
      end

      3.foo(2) do |x, i|
        x + i
      end
    ").to_i).to eq(5)
  end

  it "allows access to local variables" do
    expect(run("
      def foo
        yield
      end

      x = 1
      foo do
        x + 1
      end
    ").to_i).to eq(2)
  end

  it "can access instance vars from yielder function" do
    expect(run("
      class Foo
        def initialize
          @x = 1
        end
        def foo
          yield @x
        end
      end

      Foo.new.foo do |x|
        x + 1
      end
    ").to_i).to eq(2)
  end

  it "can set instance vars from yielder function" do
    expect(run("
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
    ").to_i).to eq(2)
  end

  it "can use instance methods from yielder function" do
    expect(run("
      class Foo
        def foo
          yield value
        end
        def value
          1
        end
      end

      Foo.new.foo { |x| x + 1 }
    ").to_i).to eq(2)
  end

  it "can call methods from block when yielder is an instance method" do
    expect(run("
      class Foo
        def foo
          yield
        end
      end

      def bar
        1
      end

      Foo.new.foo { bar }
    ").to_i).to eq(1)
  end

  it "nested yields" do
    expect(run("
      def bar
        yield
      end

      def foo
        bar { yield }
      end

      a = foo { 1 }
    ").to_i).to eq(1)
  end

  it "assigns yield to argument" do
    expect(run("
      def foo(x)
        yield
        x = 1
      end

      foo(1) { 1 }
      ").to_i).to eq(1)
  end

  it "can use global constant" do
    expect(run("
      FOO = 1
      def foo
        yield
        FOO
      end
      foo { }
    ").to_i).to eq(1)
  end

  it "return from yielder function" do
    expect(run("
      def foo
        yield
        return 1
      end

      foo { }
      2
    ").to_i).to eq(2)
  end

  it "return from block" do
    expect(run("
      def foo
        yield
      end

      def bar
        foo { return 1 }
        2
      end

      bar
    ").to_i).to eq(1)
  end

  it "return from yielder function (2)" do
    expect(run("
      def foo
        yield
        return 1 if true
        return 2
      end

      def bar
        foo {}
      end

      bar
    ").to_i).to eq(1)
  end

  it "union value of yielder function" do
    expect(run("
      def foo
        yield
        a = 1.1
        a = 1
        a
      end

      foo {}.to_i
    ").to_i).to eq(1)
  end

  it "allow return from function called from yielder function" do
    expect(run("
      def foo
        return 2
      end

      def bar
        yield
        foo
        1
      end

      bar {}
    ").to_i).to eq(1)
  end

  it "" do
    expect(run("
      def foo
        yield
        true ? return 1 : return 1.1
      end

      foo {}.to_i
    ").to_i).to eq(1)
  end

  it "return from block that always returns from function that always yields inside if block" do
    expect(run("
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
    ").to_i).to eq(1)
  end

  it "return from block that always returns from function that conditionally yields" do
    expect(run("
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
    ").to_i).to eq(1)
  end

  it "call block from dispatch" do
    expect(run("
      def bar(y)
        yield y
      end

      def foo
        x = 1.1
        x = 1
        bar(x) { |z| z }
      end

      foo.to_i
    ").to_i).to eq(1)
  end

  it "call block from dispatch and use local vars" do
    expect(run("
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
    ").to_i).to eq(4)
  end

  it "break without value returns nil" do
    expect(run("
      require \"nil\"
      require \"value\"

      def foo
        yield
        1
      end

      x = foo do
        break if 1 == 1
      end

      x.nil?
    ").to_b).to be_true
  end

  it "break block with yielder inside while" do
    expect(run("
      require \"prelude\"
      a = 0
      10.times do
        a += 1
        break if a > 5
      end
      a
    ").to_i).to eq(6)
  end

  it "break from block returns from yielder" do
    expect(run("
      def foo
        yield
        yield
      end

      a = 0
      foo { a += 1; break }
      a
    ").to_i).to eq(1)
  end

  it "break from block with value" do
    expect(run("
      def foo
        while true
          yield
          a = 3
        end
      end

      foo do
        break 1
      end
    ").to_i).to eq(1)
  end

  it "returns from block with value" do
    expect(run("
      require \"prelude\"

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
    ").to_i).to eq(1)
  end

  it "doesn't codegen after while that always yields and breaks" do
    expect(run("
      def foo
        while true
          yield
        end
        1
      end

      foo do
        break 2
      end
    ").to_i).to eq(2)
  end

  it "break from block with value" do
    expect(run("
      require \"prelude\"
      10.times { break 20 }
    ").to_i).to eq(20)
  end

  it "doesn't codegen call if arg yields and always breaks" do
    expect(run("
      require \"nil\"

      def foo
        1 + yield
      end

      foo { break 2 }.to_i
    ").to_i).to eq(2)
  end

  it "codegens nested return" do
    expect(run("
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
    ").to_i).to eq(2)
  end

  it "codegens nested break" do
    expect(run("
      def bar
        yield
        a = 1
      end

      def foo
        bar { yield }
      end

      foo { break 2 }
    ").to_i).to eq(2)
  end

  it "codegens call with block with call with arg that yields" do
    expect(run("
      def bar
        yield
        a = 2
      end

      def foo
        bar { 1 + yield }
      end

      foo { break 3 }
    ").to_i).to eq(3)
  end

  it "can break without value from yielder that returns nilable (1)" do
    expect(run("
      require \"nil\"
      require \"reference\"

      def foo
        yield
        \"\"
      end

      a = foo do
        break
      end

      a.nil?
    ").to_b).to be_true
  end

  it "can break without value from yielder that returns nilable (2)" do
    expect(run("
      require \"nil\"
      require \"reference\"

      def foo
        yield
        \"\"
      end

      a = foo do
        break nil
      end

      a.nil?
    ").to_b).to be_true
  end

  it "break with value from yielder that returns a nilable" do
    expect(run("
      require \"nil\"
      require \"reference\"

      def foo
        yield
        \"\"
      end

      a = foo do
        break if false
        break \"\"
      end

      a.nil?
    ").to_b).to be_false
  end

  it "can use self inside a block called from dispatch" do
    expect(run("
      require \"nil\"

      class Foo
        def do; yield; end
      end
      class Bar < Foo
      end


      struct Int
        def foo
          x = Foo.new
          x = Bar.new
          x.do { $x = self }
        end
      end

      123.foo
      $x.to_i
    ").to_i).to eq(123)
  end

  it "return from block called from dispatch" do
    expect(run("
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
    ").to_i).to eq(1)
  end

  it "breaks from while in function called from block" do
    expect(run("
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
    ").to_i).to eq(2)
  end

  it "allows modifying yielded value (with literal)" do
    expect(run("
      def foo
        yield 1
      end

      foo { |x| x = 2; x }
    ").to_i).to eq(2)
  end

  it "allows modifying yielded value (with variable)" do
    expect(run("
      def foo
        a = 1
        yield a
        a
      end

      foo { |x| x = 2; x }
    ").to_i).to eq(1)
  end

  it "it yields nil from another call" do
    run("
      require \"bool\"

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
    ")
  end

  it "allows yield from dispatch call" do
    expect(run("
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
    ").to_i).to eq(1)
  end

  it "block with nilable type" do
    run("
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
    ")
  end

  it "block with nilable type 2" do
    run("
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
    ")
  end

  it "allows yields with less arguments than in block" do
    expect(run("
      struct Nil
        def to_i
          0
        end
      end

      def foo
        yield 1
      end

      a = 0
      foo do |x, y|
        a += x + y.to_i
      end
      a
      ").to_i).to eq(1)
  end

  it "codegens block with nilable type with return (1)" do
    expect(run("
      struct Nil; def nil?; true; end; end
      class Reference; def nil?; false; end; end

      def foo
        if yield
          return Reference.new
        end
        nil
      end

      foo { false }.nil?
      ").to_b).to be_true
  end

  it "codegens block with nilable type with return (2)" do
    expect(run("
      struct Nil; def nil?; true; end; end
      class Reference; def nil?; false; end; end

      def foo
        if yield
          return nil
        end
        Reference.new
      end

      foo { false }.nil?
      ").to_b).to be_false
  end

  it "codegens block with union with return" do
    run("
      def foo
        yield

        return 1 if 1 == 2

        nil
      end

      x = foo { }
      1
      ")
  end

  it "codegens if with call with block (ssa issue)" do
    expect(run("
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
      ").to_i).to eq(3)
  end

  it "codegens block with return and yield and no return" do
    expect(run("
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
      ").to_i).to eq(2)
  end

  it "codegens while/break inside block" do
    expect(run("
      def foo
        yield
      end

      foo do
        while true
          break
        end
        1
      end
    ").to_i).to eq(1)
  end

  it "codegens block with union arg (1)" do
    expect(run("
      def foo
        yield 1 || 1.5
      end

      foo { |x| x }.to_i
      ").to_i).to eq(1)
  end

  it "codegens block with union arg (2)" do
    expect(run("
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
      end.to_i
      ").to_i).to eq(1)
  end

  it "codegens block with virtual type arg" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "codegens call with blocks of different type without args" do
    expect(run("
      def foo
        yield
      end

      foo { 1.1 }
      foo { 1 }
    ").to_i).to eq(1)
  end

  it "codegens dispatch with block and break (1)" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "codegens dispatch with block and break (2)" do
    expect(run("
      require \"prelude\"

      a = [1, 2, 3] || [1.5]
      n = 0
      a.each do |x|
        break if x > 2
        n += x
      end
      n.to_i
      ").to_i).to eq(3)
   end

  it "codegens block call when argument type changes" do
    run("
      def foo(x)
        while 1 == 2
          x = 1.5
          yield
        end
      end

      foo(1) do
      end
      ")
  end

  it "returns void when called with block" do
    run("
      fun foo : Void
      end

      def bar
        yield
        foo
      end

      bar {}
      ")
  end

  it "executes yield expression if no arg is given for block" do
    expect(run("
      def foo
        a = 1
        yield (a = 2)
        a
      end

      foo { }
      ").to_i).to eq(2)
  end

  it "codegens bug with block and arg and var" do
    expect(run("
      def foo
        yield 1
      end

      foo { |a| x = a }

      foo do
        a = 'A'
        a.ord
      end
      ").to_i).to eq(65)
  end

  it "allows using var as block arg with outer var" do
    expect(run("
      def foo
        yield 'a'
      end

      a = foo do |a|
        1
      end
      ").to_i).to eq(1)
  end

  it "allows initialize with yield (#224)" do
    expect(run(%(
      class Foo
        def initialize
          @x = yield 1
        end

        def x
          @x
        end
      end

      foo = Foo.new do |a|
        a + 1
      end
      foo.x
      )).to_i).to eq(2)
  end

  it "uses block inside array literal (bug)" do
    expect(run(%(
      require "prelude"

      def foo
        yield 1
      end

      ary = [foo { |x| x.abs }]
      ary[0]
      )).to_i).to eq(1)
  end

  it "codegens method invocation on a object of a captured block with a type that was never instantiated" do
    build(%(
      require "prelude"

      class Bar
        def initialize(@bar)
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
      ))
  end

  it "codegens method invocation on a object of a captured block with a type that was never instantiated (2)" do
    build(%(
      require "prelude"

      class Bar
        def initialize(@bar)
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
      ))
  end

  it "codegens bug with yield not_nil! that is never not nil" do
    expect(run(%(
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

        def to_i
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
          extra + key
        end
      end

      extra.to_i
      )).to_i).to eq(1)
  end

  it "uses block var with same name as local var" do
    expect(run(%(
      def foo
        yield "hello"
      end

      a = 1
      foo do |a|
        a
      end
      a
      )).to_i).to eq(1)
  end

  it "doesn't crash on untyped array to_s" do
    expect(run(%(
      require "prelude"

      class Bar(T)
      end

      class Foo(K)
        def foo
          Array(typeof(yield @foo.not_nil!)).new
        end
      end

      Foo(Int32).new.foo { |k| k + 1 }.to_s
      )).to_string).to eq("[]")
  end

  it "codegens block which always breaks but never enters (#494)" do
    expect(run(%(
      def foo
        while 1 == 2
          yield
        end
        3
      end

      foo do
        break 10
      end
      )).to_i).to eq(3)
  end
end
