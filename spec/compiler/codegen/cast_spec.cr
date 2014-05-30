#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: cast" do
  it "allows casting object to pointer and back" do
    run("
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      f = Foo.new(1)
      p = f as Void*
      f = p as Foo
      f.x
      ").to_i.should eq(1)
  end
end
