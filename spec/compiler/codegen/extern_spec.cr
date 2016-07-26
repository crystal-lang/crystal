require "../../spec_helper"

describe "Codegen: extern struct" do
  it "declares extern struct with no constructor" do
    run(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      Foo.new.x
      )).to_i.should eq(0)
  end

  it "declares extern struct with no constructor, assigns var" do
    run(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def x=(@x)
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x = 10
      foo.x
      )).to_i.should eq(10)
  end

  it "declares extern union with no constructor" do
    run(%(
      @[Extern(union: true)]
      struct Foo
        @x = uninitialized Int32
        @y = uninitialized Float32

        def x=(@x)
        end

        def x
          @x
        end

        def y=(@y)
        end
      end

      foo = Foo.new
      foo.x = 1
      foo.y = 1.5_f32
      foo.x
      )).to_i.should eq(1069547520)
  end

  it "declares extern struct, sets and gets insance var" do
    run(%(
      @[Extern]
      struct Foo
        @y = uninitialized Float64
        @x = uninitialized Int32

        def foo
          @x = 42
          @x
        end
      end

      Foo.new.foo
      )).to_i.should eq(42)
  end

  it "declares extern union, sets and gets insance var" do
    run(%(
      @[Extern(union: true)]
      struct Foo
        @x = uninitialized Int32
        @y = uninitialized Float32

        def foo
          @x = 1
          @y = 1.5_f32
          @x
        end
      end

      Foo.new.foo
      )).to_i.should eq(1069547520)
  end

  it "sets callback on extern struct" do
    run(%(
      require "prelude"

      @[Extern]
      struct Foo
        @x = uninitialized -> Int32

        def set
          @x = ->{ 42 }
        end

        def get
          @x.call
        end
      end

      foo = Foo.new
      foo.set
      foo.get
      )).to_i.should eq(42)
  end

  it "sets callback on extern union" do
    run(%(
      require "prelude"

      @[Extern(union: true)]
      struct Foo
        @y = uninitialized Float64
        @x = uninitialized -> Int32

        def set
          @x = ->{ 42 }
        end

        def get
          @x.call
        end
      end

      foo = Foo.new
      foo.set
      foo.get
      )).to_i.should eq(42)
  end
end
