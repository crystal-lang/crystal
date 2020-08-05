require "../../spec_helper"

describe "Code gen: op assign" do
  it "evaluates exps once (#3398)" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "evaluates exps once, [] (#3398)" do
    run(%(
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
      )).to_i.should eq(11)
  end
end
