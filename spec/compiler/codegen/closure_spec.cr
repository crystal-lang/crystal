require "../../spec_helper"

describe "Code gen: closure" do
  it "codegens simple closure at global scope" do
    run("
      a = 1
      foo = ->{ a }
      foo.call
    ").to_i.should eq(1)
  end

  it "codegens simple closure in function" do
    run("
      def foo
        a = 1
        ->{ a }
      end

      foo.call
    ").to_i.should eq(1)
  end

  it "codegens simple closure in function with argument" do
    run("
      def foo(a)
        ->{ a }
      end

      foo(1).call
    ").to_i.should eq(1)
  end

  it "codegens simple closure in block" do
    run("
      def foo
        yield
      end

      f = foo do
        x = 1
        -> { x }
      end

      f.call
    ").to_i.should eq(1)
  end

  it "codegens closured nested in block" do
    run("
      def foo
        yield
      end

      a = 1
      f = foo do
        b = 2
        -> { a + b }
      end
      f.call
    ").to_i.should eq(3)
  end

  it "codegens closured nested in block with a call with a closure with same names" do
    run("
      def foo
        a = 3
        f = -> { a }
        yield f.call
      end

      a = 1
      f = foo do |x|
        -> { a + x }
      end
      f.call
    ").to_i.should eq(4)
  end

  it "codegens closure with block that declares same var" do
    run("
      def foo
        a = 1
        yield a
      end

      f = foo do |x|
        a = 2
        -> { a + x }
      end
      f.call
      ").to_i.should eq(3)
  end

  it "codegens closure with def that has an if" do
    run("
      def foo
        yield 1 if 1
        yield 2
      end

      f = foo do |x|
        -> { x }
      end
      f.call
      ").to_i.should eq(2)
  end

  it "codegens multiple nested blocks" do
    run("
      def foo
        yield 1
        yield 2
        yield 3
      end

      a = 1
      f = foo do |x|
        b = 1
        foo do |y|
          c = 1
          -> { a + b + c + x + y }
        end
      end
      f.call
      ").to_i.should eq(9)
  end

  it "codegens closure with nested context without new closured vars" do
    run("
      def foo
        yield
      end

      a = 1
      f = foo do
        -> { a }
      end
      f.call
      ").to_i.should eq(1)
  end

  it "codegens closure with nested context without new closured vars" do
    run("
      def foo
        yield
      end

      def bar
        yield
      end

      a = 1
      f = foo do
        b = 1
        bar do
          -> { a + b }
        end
      end
      f.call
      ").to_i.should eq(2)
  end

  it "codegens closure with nested context without new closured vars but with block arg" do
    run("
      def foo
        yield
      end

      def bar
        yield 3
      end

      a = 1
      f = foo do
        b = 1
        bar do |x|
          x
          -> { a + b }
        end
      end
      f.call
      ").to_i.should eq(2)
  end

  it "unifies types of closured var" do
    run("
      a = 1
      f = -> { a }
      a = 2.5
      f.call.to_i
      ").to_i.should eq(2)
  end

  it "codegens closure with block" do
    run("
      def foo
        yield
      end

      a = 1
      ->{ foo { a } }.call
      ").to_i.should eq(1)
  end

  it "codegens closure with self and var" do
    run("
      class Foo
        def initialize(@x : Int32)
        end

        def foo
          a = 2
          ->{ self.x + a }
        end

        def x
          @x
        end
      end

      Foo.new(1).foo.call
      ").to_i.should eq(3)
  end

  it "codegens closure with implicit self and var" do
    run("
      class Foo
        def initialize(@x : Int32)
        end

        def foo
          a = 2
          ->{ x + a }
        end

        def x
          @x
        end
      end

      Foo.new(1).foo.call
      ").to_i.should eq(3)
  end

  it "codegens closure with instance var and var" do
    run("
      class Foo
        def initialize(@x : Int32)
        end

        def foo
          a = 2
          ->{ @x + a }
        end
      end

      Foo.new(1).foo.call
      ").to_i.should eq(3)
  end

  it "codegens closure with instance var" do
    run("
      class Foo
        def initialize(@x : Int32)
        end

        def foo
          ->{ @x }
        end
      end

      Foo.new(1).foo.call
      ").to_i.should eq(1)
  end

  it "codegens closure with instance var and block" do
    run("
      def bar
        yield
      end

      class Foo
        def initialize(@x : Int32)
        end

        def foo
          bar do
            a = 2
            ->{ @x + a }
          end
        end
      end

      Foo.new(1).foo.call
      ").to_i.should eq(3)
  end

  it "codegen closure in instance method without self closured" do
    run("
      class Foo
        def foo
          ->(a : Int32) { a }
        end
      end

      Foo.new.foo.call(1)
      ").to_i.should eq(1)
  end

  it "codegens closure inside initialize inside block with self" do
    run("
      def foo
        yield
      end

      class Foo
        def initialize
          -> { self }
        end
      end

      foo do
        Foo.new
      end
      ")
  end

  it "doesn't free closure memory (bug)" do
    run(%(
      require "prelude"

      def foo
        i = 0
        while i < 50_000
          yield i
          i += 1
        end
      end

      funcs = [] of -> Int32

      foo do |x|
        funcs.push(->{ x })
      end

      a = 0_i64
      funcs.each do |func|
        a += func.call
      end
      a
      )).to_i.should eq(1249975000_i64)
  end

  it "codegens nested closure" do
    run(%(
      a = 1
      ->{ ->{ a } }.call.call
      )).to_i.should eq(1)
  end

  it "codegens super nested closure" do
    run(%(
      a = 1
      ->{ ->{ -> { -> { a } } } }.call.call.call.call
      )).to_i.should eq(1)
  end

  it "codegens nested closure with block (1)" do
    run(%(
      def foo
        yield
      end

      a = 1
      ->{ foo { ->{ a } } }.call.call
      )).to_i.should eq(1)
  end

  it "codegens nested closure with block (2)" do
    run(%(
      def foo
        yield
      end

      a = 1
      ->{ ->{ foo { a } } }.call.call
      )).to_i.should eq(1)
  end

  it "codegens nested closure with nested closured variable" do
    run(%(
      a = 1
      ->{
        b = 2
        ->{ a + b }
      }.call.call
      )).to_i.should eq(3)
  end

  it "codegens super nested closure with nested closured variable" do
    run(%(
      def foo
        yield 4
      end

      a = 1
      ->{
        b = 2
        ->{
          -> {
            -> {
              c = 3
              foo do |d|
                -> {
                  a + b + c + d
                }
              end
            }
          }
        }
      }.call.call.call.call.call
      )).to_i.should eq(10)
  end

  it "codegens proc literal with struct" do
    run(%(
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      f = ->(foo : Foo) { foo.x }

      obj = Foo.new(2)
      f.call(obj)
      )).to_i.should eq(2)
  end

  it "codegens closure with struct" do
    run(%(
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      a = 1
      f = ->(foo : Foo) {
        foo.x + a
      }

      obj = Foo.new(2)
      f.call(obj)
      )).to_i.should eq(3)
  end

  it "codegens closure with self and arguments" do
    run(%(
      class Foo
        def initialize(@x : Int32)
        end

        def foo(x)
          @x + x
        end

        def bar
          ->foo(Int32)
        end
      end

      f = Foo.new(1).bar
      f.call(2)
      )).to_i.should eq(3)
  end

  it "codegens nested closure that mentions var in both contexts" do
    run(%(
      a = 1
      f = ->{
        a
        -> { a }
      }
      f.call.call
      )).to_i.should eq(1)
  end

  it "transforms block to proc literal" do
    run("
      def foo(&block : Int32 -> Int32)
        block.call(1)
      end

      a = 1
      foo do |x|
        x + a
      end
      ").to_i.should eq(2)
  end

  it "transforms block to proc literal with free var" do
    run("
      def foo(&block : Int32 -> U) forall U
        block
      end

      a = 1
      g = foo { |x| x + a }
      h = foo { |x| x.to_f + a }
      (g.call(3) + h.call(5)).to_i
      ").to_i.should eq(10)
  end

  it "allows passing block as proc literal to new and to initialize" do
    run("
      class Foo
        def initialize(&block : Int32 -> Float64)
          @block = block
        end

        def block
          @block
        end
      end

      a = 1
      foo = Foo.new { |x| x.to_f + a }
      foo.block.call(1).to_i
      ").to_i.should eq(2)
  end

  it "allows giving less block args when transforming block to proc literal" do
    run("
      def foo(&block : Int32 -> U) forall U
        block.call(1)
      end

      a = 1
      v = foo do
        1.5 + a
      end
      v.to_i
      ").to_i.should eq(2)
  end

  it "allows passing proc literal to def that captures block with &" do
    run("
      def foo(&block : Int32 -> Int32)
        block.call(1)
      end

      a = 1
      f = ->(x : Int32) { x + a }
      foo &f
      ").to_i.should eq(2)
  end

  it "allows mixing yield and block.call" do
    run(%(
      def foo(&block : Int32 ->)
        yield 1
        block.call 2
      end

      a = 0
      foo { |x| a += x }
      a
      )).to_i.should eq(3)
  end

  it "closures struct self" do
    run(%(
      struct Foo
        def initialize(@x : Int32)
        end

        def foo
          ->{ @x }
        end
      end

      Foo.new(1).foo.call
      )).to_i.should eq(1)
  end

  it "doesn't form a closure if invoking class method" do
    run(%(
      require "prelude"

      class Foo
        def self.foo
          ->{ bar }.closure?
        end

        def self.bar
        end
      end

      Foo.foo
      )).to_b.should be_false
  end

  it "doesn't form a closure if invoking class method with self" do
    run(%(
      require "prelude"

      class Foo
        def self.foo
          ->{ self.bar }.closure?
        end

        def self.bar
        end
      end

      Foo.foo
      )).to_b.should be_false
  end

  it "captures block and accesses local variable (#2050)" do
    run(%(
      require "prelude"

      def capture(&block)
        block
      end

      coco = 1
      capture do
        coco
      end
      coco
      )).to_i.should eq(1)
  end

  it "codegens closured self in block (#3388)" do
    run(%(
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end

        def foo
          yield
          ->{ self }
        end
      end

      foo = Foo.new(42)
      foo2 = foo.foo { }
      foo2.call.x
      )).to_i.should eq(42)
  end

  it "doesn't incorrectly consider local as closured (#4948)" do
    codegen(%(
      arg = 1

      f1 = ->{
        # Here 'local' isn't to be confused with
        # the outer closured 'local'
        local = 1
        local + arg
      }

      arg = 2

      local = 4_i64
      f2 = ->{ local.to_i }

      f1.call + f2.call
    ))
  end
end
