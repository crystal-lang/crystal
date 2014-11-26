require "../../spec_helper"

describe "Code gen: alias" do
  it "invokes methods on empty array of recursive alias (1)" do
    run(%(
      require "prelude"

      alias X = Array(X)

      a = [] of X
      b = a.map(&.to_s).join
      )).to_string.should eq("")
  end

  it "invokes methods on empty array of recursive alias (2)" do
    run(%(
      require "prelude"

      alias X = Nil | Array(X)

      a = [] of X
      b = a.map(&.to_s).join
      )).to_string.should eq("")
  end

  it "invokes methods on empty array of recursive alias (3)" do
    run(%(
      require "prelude"

      alias X = Nil | Array(X)

      a = [] of X
      b = a.map(&.to_s).join
      )).to_string.should eq("")
  end

  it "casts to recursive alias" do
    run(%(
      require "prelude"

      class Bar(T)
      end

      alias Foo = Int32 | Bar(Foo)

      a = 1 as Foo
      b = a as Int32
      b
      )).to_i.should eq(1)
  end

  it "casts to recursive alias" do
    run(%(
      class Bar(T)
        def self.new(&block : -> T)
        end

        def to_i
          0
        end
      end

      alias Foo = Int32 | Bar(Foo)

      def foo(n)
        if n == 0
          1
        else
          foo(n - 1) as Foo
        end
      end

      foo(2).to_i
      )).to_i.should eq(1)
  end
end
