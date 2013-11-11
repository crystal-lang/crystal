#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Codegen: const" do
  it "declaring var" do
    run("
      BAR = begin
        a = 1
        while 1 == 2
          b = 2
        end
        a
      end
      class Foo
        def compile
          BAR
        end
      end

      Foo.new.compile
      ").to_i.should eq(1)
  end
end
