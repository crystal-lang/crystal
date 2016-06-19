require "../../spec_helper"

describe "Code gen: nilable cast" do
  it "does nilable cast (true)" do
    run(%(
      x = 42 || "hello"
      y = x.as?(Int32)
      y || 84
      )).to_i.should eq(42)
  end

  it "does nilable cast (false)" do
    run(%(
      x = "hello" || 42
      y = x.as?(Int32)
      y || 84
      )).to_i.should eq(84)
  end

  it "does nilable cast (always true)" do
    run(%(
      x = 42
      y = x.as?(Int32)
      y || 84
      )).to_i.should eq(42)
  end

  it "does upcast" do
    run(%(
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
      )).to_i.should eq(2)
  end

  it "does cast to nil (1)" do
    run(%(
      x = 1
      y = x.as?(Nil)
      y ? 2 : 3
      )).to_i.should eq(3)
  end

  it "does cast to nil (2)" do
    run(%(
      x = nil
      y = x.as?(Nil)
      y ? 2 : 3
      )).to_i.should eq(3)
  end

  it "types as? with wrong type (#2775)" do
    run(%(
      x = 1.as?(String)
      x ? 10 : 20
      )).to_i.should eq(20)
  end
end
