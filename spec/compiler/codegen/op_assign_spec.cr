require "../../spec_helper"

describe "Code gen: op assign" do
  it "evaluates exps once (#3398)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Global
        @@value = 0

        def self.value
          @@value
        end

        def self.value=(@@value)
        end
      end

      class Foo
        def bar=(bar)
        end

        def bar
          0
        end
      end

      def foo
        Global.value &+= 1
        Foo.new
      end

      foo.bar &+= 2

      Global.value
      CRYSTAL
  end

  it "evaluates exps once, [] (#3398)" do
    run(<<-CRYSTAL).to_i.should eq(11)
      class Global
        @@value = 0

        def self.value
          @@value
        end

        def self.value=(@@value)
        end
      end

      class Foo
        def [](v)
          0
        end

        def []=(k, v)
        end
      end

      def foo
        Global.value &+= 1
        Foo.new
      end

      def bar
        Global.value &+= 10
        0
      end

      foo[bar] &+= 2

      Global.value
      CRYSTAL
  end

  it "evaluates index receiver before indices (#17921)" do
    run(<<-CRYSTAL).to_i.should eq(11)
      lib LibC
        fun exit(status : Int32) : NoReturn
      end

      fun __crystal_raise_overflow : NoReturn
        LibC.exit(1)
      end

      class Box
        def initialize(@value : Int32)
        end

        def value
          @value
        end

        def [](index)
          @value
        end

        def []=(index, value)
          @value = value
        end
      end

      a = Box.new(10)
      b = Box.new(30)
      flag = false
      (flag = !flag; flag ? a : b)[(flag = !flag) ? 1 : 0] += 1
      a.value
      CRYSTAL
  end
end
