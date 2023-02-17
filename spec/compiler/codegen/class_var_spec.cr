require "../../spec_helper"

describe "Codegen: class var" do
  it "codegens class var" do
    run("
      class Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "codegens class var as nil" do
    run("
      struct Nil; def to_i; 0; end; end

      class Foo
        @@foo = nil

        def self.foo
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i.should eq(0)
  end

  it "codegens class var inside instance method" do
    run("
      class Foo
        @@foo = 1

        def foo
          @@foo
        end
      end

      Foo.new.foo
      ").to_i.should eq(1)
  end

  it "codegens class var as nil if assigned for the first time inside method" do
    run("
      struct Nil; def to_i!; 0; end; end

      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo.to_i!
      ").to_i.should eq(1)
  end

  it "codegens class var inside module" do
    run("
      module Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "accesses class var from proc literal" do
    run("
      class Foo
        @@a = 1

        def self.foo
          ->{ @@a }.call
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "reads class var before initializing it (hoisting)" do
    run(%(
      x = Foo.var

      class Foo
        @@var = 42

        def self.var
          @@var
        end
      end

      x
      )).to_i.should eq(42)
  end

  it "uses var in class var initializer" do
    run(%(
      require "prelude"

      class Foo
        @@var : Int32
        @@var = begin
          a = class_method
          a &+ 3
        end

        def self.var
          @@var
        end

        def self.class_method
          1 &+ 2
        end
      end

      Foo.var
      )).to_i.should eq(6)
  end

  it "reads simple class var before another complex one" do
    run(%(
      require "prelude"

      class Foo
        @@var2 : Int32
        @@var2 = @@var &+ 1

        @@var = 41

        def self.var2
          @@var2
        end
      end

      Foo.var2
      )).to_i.should eq(42)
  end

  it "initializes class var of union with single type" do
    run(%(
      require "prelude"

      class Foo
        @@var : Int32 | String
        @@var = 42

        def self.var
          @@var
        end
      end

      var = Foo.var
      if var.is_a?(Int32)
        var
      else
        0
      end
      )).to_i.should eq(42)
  end

  it "initializes class var with array literal" do
    run(%(
      require "prelude"

      class Foo
        @@var = [1, 2, 4]

        def self.var
          @@var
        end
      end

      Foo.var.size
      )).to_i.should eq(3)
  end

  it "codegens second class var initializer" do
    run(%(
      class Foo
        @@var = 1
        @@var = 2

        def self.var
          @@var
        end
      end

      Foo.var
      )).to_i.should eq(2)
  end

  it "initializes dependent constant before class var" do
    run(%(
      require "prelude"

      def foo
        a = 1
        b = 2
        a &+ b
      end

      CONST = foo()

      class Foo
        @@foo : Int32
        @@foo = CONST

        def self.foo
          @@foo
        end
      end

      Foo.foo
      )).to_i.should eq(3)
  end

  it "declares and initializes" do
    run(%(
      class Foo
        @@x : Int32 = 42

        def self.x
          @@x
        end
      end

      Foo.x
      )).to_i.should eq(42)
  end

  it "doesn't use nilable type for initializer" do
    run(%(
      require "prelude"

      class Foo
        @@foo : Int32?
        @@foo = 42

        @@bar : Int32?
        @@bar = @@foo

        def self.bar
          @@bar
        end
      end

      Foo.bar || 10
      )).to_i.should eq(42)
  end

  it "codegens class var with begin and vars" do
    run(%(
      require "prelude"

      class Foo
        @@foo : Int32
        @@foo = begin
          a = 1
          b = 2
          a &+ b
        end

        def self.foo
          @@foo
        end
      end

      Foo.foo
      )).to_i.should eq(3)
  end

  it "codegens class var with type declaration begin and vars" do
    run(%(
      require "prelude"

      class Foo
        @@foo : Int32 = begin
          a = 1
          b = 2
          a &+ b
        end

        def self.foo
          @@foo
        end
      end

      Foo.foo
      )).to_i.should eq(3)
  end

  it "codegens class var with nilable reference type" do
    run(%(
      class Foo
        @@foo : String? = nil

        def self.foo
          @@foo ||= "hello"
        end
      end

      Foo.foo
      )).to_string.should eq("hello")
  end

  it "initializes class var the moment it reaches it" do
    run(%(
      require "prelude"

      ENV["FOO"] = "BAR"

      class Foo
        @@x = ENV["FOO"]

        def self.x
          @@x
        end
      end

      w = Foo.x
      z = Foo.x
      z
      )).to_string.should eq("BAR")
  end

  it "gets pointerof class var" do
    run(%(
      z = Foo.foo

      class Foo
        @@foo = 10

        def self.foo
          pointerof(@@foo).value
        end
      end

      z
      )).to_i.should eq(10)
  end

  it "gets pointerof class var complex constant" do
    run(%(
      require "prelude"

      z = Foo.foo

      class Foo
        @@foo : Int32
        @@foo = begin
          a = 10
          a
        end

        def self.foo
          pointerof(@@foo).value
        end
      end

      z
      )).to_i.should eq(10)
  end

  it "doesn't inherit class var value in subclass" do
    run(%(
      class Foo
        @@var = 1

        def self.var
          @@var
        end

        def self.var=(@@var)
        end
      end

      class Bar < Foo
      end

      Foo.var = 2

      Bar.var
      )).to_i.should eq(1)
  end

  it "doesn't inherit class var value in module" do
    run(%(
      module Moo
        @@var = 1

        def var
          @@var
        end

        def self.var=(@@var)
        end
      end

      class Foo
        include Moo
      end

      Moo.var = 2

      Foo.new.var
      )).to_i.should eq(1)
  end

  it "reads class var from virtual type" do
    run(%(
      class Foo
        @@var = 1

        def self.var=(@@var)
        end

        def self.var
          @@var
        end

        def var
          @@var
        end
      end

      class Bar < Foo
      end

      Bar.var = 2

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value.var
      )).to_i.should eq(2)
  end

  it "reads class var from virtual type metaclass" do
    run(%(
      class Foo
        @@var = 1

        def self.var=(@@var)
        end

        def self.var
          @@var
        end
      end

      class Bar < Foo
      end

      Bar.var = 2

      ptr = Pointer(Foo.class).malloc(1_u64)
      ptr.value = Bar
      ptr.value.var
      )).to_i.should eq(2)
  end

  it "writes class var from virtual type" do
    run(%(
      class Foo
        @@var = 1

        def self.var=(@@var)
        end

        def self.var
          @@var
        end

        def var=(@@var)
        end
      end

      class Bar < Foo
      end

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value.var = 2

      Bar.var
      )).to_i.should eq(2)
  end

  it "declares var as uninitialized and initializes it unsafely" do
    run(%(
      class Foo
        @@x = uninitialized Int32
        @@x = Foo.bar

        def self.bar
          if 1 == 2
            @@x
          else
            10
          end
        end

        def self.x
          @@x
        end
      end

      Foo.x
      )).to_i.should eq(10)
  end

  it "doesn't crash with pointerof from another module" do
    run(%(
      require "prelude"

      class Foo
        @@x : Int32?
        @@x = 1

        def self.x
          pointerof(@@x).value
        end
      end

      class Bar
        def self.bar
          Foo.x
        end
      end

      Bar.bar
      )).to_i.should eq(1)
  end

  it "codegens generic class with class var" do
    run(%(
      class Foo(T)
        @@bar = 1

        def bar
          @@bar
        end

        def bar=(@@bar)
        end
      end

      f1 = Foo(Int32).new
      f2 = Foo(String).new

      a = f1.bar
      b = f2.bar
      f1.bar = 10
      c = f2.bar
      f2.bar = 20
      d = f1.bar
      a &+ b &+ c &+ d
      )).to_i.should eq(1 + 1 + 10 + 20)
  end

  it "inline initialization of simple class var" do
    mod = codegen(%(
      class Foo
        @@x = 1
      end
    ))

    mod.to_s.should_not contain("x:init")
  end

  it "catch infinite loop in class var initializer" do
    run(%(
      require "prelude"

      module Crystal
        def self.main_user_code(argc : Int32, argv : UInt8**)
          LibCrystalMain.__crystal_main(argc, argv)
        rescue ex
          print "error: \#{ex.message}"
        end
      end

      class Foo
        @@x : Int32 = init

        def self.init
          @@x + 1
        end

        def self.x
          @@x
        end
      end

      nil
    )).to_string.should eq("error: Recursion while initializing class variables and/or constants")
  end

  it "runs class var side effects (#8862)" do
    run(%(
      require "prelude"

      class Foo
        @@x = 0

        def self.set
          @@x = 3
        end

        def self.x
          @@x
        end
      end

      a = Hello.value

      class Hello
        @@value : Int32 = begin
          Foo.set
          1 &+ 2
        end

        def self.value
          @@value
        end
      end

      a &+ Foo.x
      )).to_i.should eq(6)
  end
end
