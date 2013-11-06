#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: macro" do
  it "expands macro" do
    run("macro foo; \"1 + 2\"; end; foo").to_i.should eq(3)
  end

  it "expands macro with arguments" do
    run("require \"bootstrap\"; macro foo(n); \"\#{n} + 2\"; end; foo(1)").to_i.should eq(3)
  end

  it "expands macro that invokes another macro" do
    run("macro foo; \"def x; 1 + 2; end\"; end; macro bar; \"foo\"; end; bar; x").to_i.should eq(3)
  end

  it "expands macro defined in class" do
    run("
      class Foo
        macro self.foo\"
          def bar; 1; end
        \"end

        foo
      end

      foo = Foo.new
      foo.bar
    ").to_i.should eq(1)
  end

  it "expands macro defined in base class" do
    run("
      class Object
        macro self.foo\"
          def bar; 1; end
        \"end
      end

      class Foo
        foo
      end

      foo = Foo.new
      foo.bar
    ").to_i.should eq(1)
  end
end
