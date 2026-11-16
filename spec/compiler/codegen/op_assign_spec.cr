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
    run(<<-CRYSTAL).to_i.should eq(192)
      class Box
        def initialize
          @value = 1
        end

        def value
          @value
        end

        def [](index)
          @value &* index
        end

        def []=(index, value)
          @value = index &* value
        end
      end

      a = Box.new
      b = 10
      (b &+= 2; a)[b] &+= 4
      a.value
      CRYSTAL
  end
end
