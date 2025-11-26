{% skip_file if flag?(:openbsd) || (flag?(:win32) && flag?(:gnu)) %}

require "../../spec_helper"

describe "Codegen: thread local" do
  it "works with class variables" do
    run(<<-CRYSTAL).to_i.should eq(123)
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
    CRYSTAL
  end

  it "works with class variable in main thread" do
    run(<<-CRYSTAL).to_i.should eq(123)
    require "prelude"

    class Foo
      @[ThreadLocal]
      @@a = 123

      def self.a
        @@a
      end
    end

    Foo.a
    CRYSTAL
  end

  it "compiles with class variable referenced from initializer" do
    run(<<-CRYSTAL)
    require "prelude"

    class Foo
      @[ThreadLocal]
      @@x : Foo?
      @@x = nil

      def self.x
        @@x ||= new
      end

      def initialize
        Foo.x
      end
    end

    0
    CRYSTAL
  end
end
