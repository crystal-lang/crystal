require "../../spec_helper"

describe "Codegen: thread local" do
  it "works with global variables" do
    run(%(
      require "prelude"

      @[ThreadLocal]
      $var = 123

      Thread.new { $var = 456 }.join

      $var
    )).to_i.should eq(123)
  end

  it "works with global variable in main thread" do
    run(%(
      require "prelude"

      @[ThreadLocal]
      $a = 123
      $a
      )).to_i.should eq(123)
  end

  it "works with class variables" do
    run(%(
      require "prelude"

      class Foo
        @[ThreadLocal]
        @@var = 123

        def self.var
          @@var
        end

        def self.var=(@@var)
        end
      end

      Thread.new { Foo.var = 456 }.join

      Foo.var
    )).to_i.should eq(123)
  end

  it "works with class variable in main thread" do
    run(%(
      require "prelude"

      class Foo
        @[ThreadLocal]
        @@a = 123

        def self.a
          @@a
        end
      end

      Foo.a
      )).to_i.should eq(123)
  end

  it "compiles with class variable referenced from initializer" do
    run(%(
      require "prelude"

      class Foo
        @[ThreadLocal]
        @@x = new

        def initialize
          @@x
        end
      end

      0
    ))
  end
end
