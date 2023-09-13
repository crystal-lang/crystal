require "../../spec_helper"

describe "Code gen: struct" do
  it "creates structs" do
    run("
      struct Foo
      end

      f = Foo.allocate
      1
      ").to_i.should eq(1)
  end

  it "creates structs with instance var" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      f = Foo.new(1)
      f.x
      ").to_i.should eq(1)
  end

  it "assigning a struct makes a copy (1)" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end

        def x=(@x)
        end
      end

      f = Foo.new(1)

      g = f
      g.x = 2

      g.x
      ").to_i.should eq(2)
  end

  it "assigning a struct makes a copy (2)" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end

        def x=(@x)
        end
      end

      f = Foo.new(1)

      g = f
      g.x = 2

      f.x
      ").to_i.should eq(1)
  end

  it "passes a struct as a parameter makes a copy" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end

        def x=(@x)
        end
      end

      def foo(f)
        f.x = 2
      end

      f = Foo.new(1)

      foo(f)

      f.x
      ").to_i.should eq(1)
  end

  it "passes a generic struct as a parameter makes a copy" do
    run("
      struct Foo(T)
        def initialize(@x : T)
        end

        def x
          @x
        end

        def x=(@x)
        end
      end

      def foo(f)
        f.x = 2
      end

      f = Foo(Int32).new(1)

      foo(f)

      f.x
      ").to_i.should eq(1)
  end

  it "returns struct as a copy" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end

        def x=(@x)
        end
      end

      def foo(f)
        f.x = 2
        f
      end

      f = Foo.new(1)

      g = foo(f)
      g.x
      ").to_i.should eq(2)
  end

  it "creates struct in def" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      def foo
        Foo.new(1)
      end

      foo.x
      ").to_i.should eq(1)
  end

  it "declares const struct" do
    run(%(
      require "prelude"

      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      FOO = Foo.new(1)

      FOO.x
      )).to_i.should eq(1)
  end

  it "uses struct in if" do
    run(%(
      require "prelude"

      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      FOO = Foo.new(1)

      if 1 == 2
        foo = Foo.new(1)
      else
        foo = FOO
      end
      foo.x
      )).to_i.should eq(1)
  end

  it "uses nilable struct" do
    run("
      struct Foo
      end

      f = Foo.new || nil
      f.nil? ? 1 : 2
      ").to_i.should eq(2)
  end

  it "returns self" do
    run("
      struct Foo
        def initialize(@x)
        end

        def foo
          @x = 2
          return self
        end

        def x
          @x
        end
      end

      f = Foo.new(1)
      g = f.foo
      g.x
      ").to_i.should eq(2)
  end

  it "returns self with block" do
    run("
      struct Foo
        def initialize(@x)
        end

        def foo
          @x = 2
          yield 1
          self
        end

        def x
          @x
        end
      end

      f = Foo.new(1)
      g = f.foo { }
      g.x
      ").to_i.should eq(2)
  end

  it "does phi of struct" do
    run("
      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      x = if 1 == 2
            Foo.new(2)
          else
            Foo.new(1)
          end
      x.x
      ").to_i.should eq(1)
  end

  it "allows assigning to struct argument (bug)" do
    run("
      struct Foo
        def bar
          2
        end
      end

      def foo(x)
        x = x.bar
      end

      foo(Foo.new)
      ").to_i.should eq(2)
  end

  it "codegens struct assigned to underscore (#1842)" do
    run(%(
      struct Foo
        def initialize
          @value = 123
        end

        def value
          @value
        end
      end

      def foo
        _ = Foo.new
      end

      foo.value
      )).to_i.should eq(123)
  end

  it "codegens virtual struct" do
    run(%(
      abstract struct Foo
      end

      struct Bar < Foo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      struct Baz < Foo
        def initialize
          @x = 2
        end

        def x
          @x
        end
      end

      foo = Bar.new || Baz.new
      foo.x
      )).to_i.should eq(1)
  end

  it "codegens virtual struct with pointer" do
    run(%(
      abstract struct Foo
      end

      struct Bar < Foo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      struct Baz < Foo
        def initialize
          @x = 2
        end

        def x
          @x
        end
      end

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Baz.new
      ptr.value = Bar.new
      ptr.value.x
      )).to_i.should eq(1)
  end

  it "codegens virtual struct metaclass (#2551) (1)" do
    run(%(
      abstract struct Foo
        def initialize
          @x = 21
        end

        def x
          a = @x
          a
        end
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end
      end

      struct Baz < Foo
      end

      Bar.new.as(Foo).x
      )).to_i.should eq(42)
  end

  it "codegens virtual struct metaclass (#2551) (2)" do
    run(%(
      abstract struct Foo
        def initialize
          @x = 21
        end
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end
      end

      struct Baz < Foo
      end

      Bar.new.as(Foo).@x
      )).to_i.should eq(42)
  end

  it "codegens virtual struct metaclass (#2551) (3)" do
    run(%(
      abstract struct Foo
        def initialize
          @x = 21
        end

        def x
          @x
        end
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end
      end

      struct Baz < Foo
      end

      Bar.new.as(Foo).x
      )).to_i.should eq(42)
  end

  it "codegens virtual struct metaclass (#2551) (4)" do
    run(%(
      require "prelude"

      abstract struct Foo
        def initialize
          @x = 21
        end

        def x
          a = @x
          a
        end
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end
      end

      struct Baz < Foo
      end

      (Bar || Baz).new.x
      )).to_i.should eq(42)
  end

  it "mutates a  virtual struct" do
    run(%(
      abstract struct Foo
        def initialize
          @x = 21
        end

        def x=(@x)
        end

        def x
          @x
        end
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end
      end

      struct Baz < Foo
      end

      foo = Bar.new.as(Foo)
      foo.x = 84
      foo.x
      )).to_i.should eq(84)
  end

  it "codegens virtual structs union (1)" do
    run(%(
      abstract struct Foo
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end

        def x
          @x
        end
      end

      abstract struct Foo2
      end

      struct Bar2 < Foo2
        def initialize
          @x = 84
        end

        def x
          @x
        end
      end

      foo = Bar.new.as(Foo)
      foo2 = Bar2.new.as(Foo2)

      f = foo || foo2
      f.x
      )).to_i.should eq(42)
  end

  it "codegens virtual structs union (2)" do
    run(%(
      abstract struct Foo
      end

      struct Bar < Foo
        def initialize
          @x = 42
        end

        def x
          @x
        end
      end

      abstract struct Foo2
      end

      struct Bar2 < Foo2
        def initialize
          @x = 84
        end

        def x
          @x
        end
      end

      foo = Bar.new.as(Foo)
      foo2 = Bar2.new.as(Foo2)

      f = foo2 || foo
      f.x
      )).to_i.should eq(84)
  end

  it "can cast virtual struct to specific struct" do
    run(%(
       require "prelude"

       abstract struct Foo
       end

       struct Bar < Foo
         def foo
           1
         end
       end

       struct Baz < Foo
         def foo
           2
         end
       end

       x = Bar.new || Baz.new
       x.as(Bar).foo
       )).to_i.should eq(1)
  end

  it "casts virtual struct to base type, only one subclass (#2885)" do
    run(%(
      abstract struct Entry
        def initialize(@uid : String, @country : String)
        end

        def uid
          @uid
        end
      end

      struct MyEntry < Entry
      end

      entry = MyEntry.new("1", "GER")
      entry.as(Entry).uid
      )).to_string.should eq("1")
  end

  it "can call new on abstract struct with single child (#7309)" do
    codegen(%(
      require "prelude"

      abstract struct Foo
        @x = 1
      end

      struct A < Foo
        @y = 2
      end

      A.as(Foo.class).new
      ), inject_primitives: false)
  end
end
