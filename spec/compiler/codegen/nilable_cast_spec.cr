require "../../spec_helper"

describe "Code gen: nilable cast" do
  it "does nilable cast (true)" do
    run(<<-CRYSTAL).to_i.should eq(42)
      x = 42 || "hello"
      y = x.as?(Int32)
      y || 84
      CRYSTAL
  end

  it "does nilable cast (false)" do
    run(<<-CRYSTAL).to_i.should eq(84)
      x = "hello" || 42
      y = x.as?(Int32)
      y || 84
      CRYSTAL
  end

  it "does nilable cast (always true)" do
    run(<<-CRYSTAL).to_i.should eq(42)
      x = 42
      y = x.as?(Int32)
      y || 84
      CRYSTAL
  end

  it "does upcast" do
    run(<<-CRYSTAL).to_i.should eq(2)
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

      foo = Bar.new.as?(Foo)
      if foo
        foo.bar
      else
        3
      end
      CRYSTAL
  end

  it "does cast to nil (1)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      x = 1
      y = x.as?(Nil)
      y ? 2 : 3
      CRYSTAL
  end

  it "does cast to nil (2)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      x = nil
      y = x.as?(Nil)
      y ? 2 : 3
      CRYSTAL
  end

  it "types as? with wrong type (#2775)" do
    run(<<-CRYSTAL).to_i.should eq(20)
      x = 1.as?(String)
      x ? 10 : 20
      CRYSTAL
  end

  it "codegens with NoReturn" do
    codegen(<<-CRYSTAL)
      lib LibC
        fun exit : NoReturn
      end

      def foo
        LibC.exit.as?(Int32)
        10
      end

      foo
      CRYSTAL
  end

  it "upcasts type to virtual (#3304)" do
    run(<<-CRYSTAL).to_i.should eq(1)
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

      f = Foo.new.as?(Foo)
      f ? f.foo : 10
      CRYSTAL
  end

  it "upcasts type to virtual (2) (#3304)" do
    run(<<-CRYSTAL).to_i.should eq(1)
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

      class Gen(T)
        def self.cast(x)
          x.as?(T)
        end
      end

      f = Gen(Foo).cast(Foo.new)
      f ? f.foo : 10
      CRYSTAL
  end

  it "casts with block var that changes type (#3341)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      class Object
        def try
          yield self
        end
      end

      class Foo
      end

      x = Foo.new.as(Int32 | Foo)
      x.try &.as?(Foo)
      CRYSTAL
  end

  it "casts union type to nilable type (#9342)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      struct Nil
        def foo
          0
        end
      end

      class Gen(T)
        def initialize(@value : Int32)
        end

        def foo
          @value
        end
      end

      a = Gen(String).new(10) || Gen(Int32).new(20)
      a.as?(Gen).foo
      CRYSTAL
  end
end
