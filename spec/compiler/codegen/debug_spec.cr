require "../../spec_helper"

describe "Code gen: debug" do
  it "codegens abstract struct (#3578)" do
    codegen(%(
      abstract struct Base
      end

      struct Foo < Base
      end

      struct Bar < Base
      end

      x = Foo.new || Bar.new
      ), debug: Crystal::Debug::All)
  end

  it "inlines instance var access through getter in debug mode" do
    run(%(
      struct Bar
        @x = 1

        def set
          @x = 2
        end

        def x
          @x
        end
      end

      class Foo
        @bar = Bar.new

        def set
          bar.set
        end

        def bar
          @bar
        end
      end

      foo = Foo.new
      foo.set
      foo.bar.x
      ), debug: Crystal::Debug::All, filename: "foo.cr").to_i.should eq(2)
  end

  it "codegens correct debug info for untyped expression (#4007 and #4008)" do
    codegen(%(
      require "prelude"

      int = 3
      case int
      when 0
          puts 0
      when 1, 2, Int32
          puts "1 | 2 | Int32"
      else
          puts int
      end
      ), debug: Crystal::Debug::All)
  end

  it "codegens correct debug info for new with custom allocate (#3945)" do
    codegen(%(
      class Foo
        def initialize
        end

        def self.allocate
          Pointer(UInt8).malloc(1_u64).as(self)
        end
      end

      Foo.new
      ), debug: Crystal::Debug::All)
  end

  it "correctly restores debug location after fun change (#4254)" do
    codegen(%(
      require "prelude"

      class Foo
        def self.one
          TWO.two { three }
          self
        end

        def self.three
          1 + 2
        end

        def two(&block)
          block
        end
      end

      ONE = Foo.one
      TWO = Foo.new

      ONE.three
      ), debug: Crystal::Debug::All)
  end
end
