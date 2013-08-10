#!/usr/bin/env bin/crystal -run
require "spec"

describe "Exception" do
  it "executes body if nothing raised" do
    x = begin
          1
        rescue
          2
        end
    x.should eq(1)
  end

  it "executes rescue if something is raised conditionally" do
    y = 1
    x = 1
    x = begin
          y == 1 ? raise "Oh no!" : nil
          y = 2
        rescue
          3
        end
    x.should eq(3)
    y.should eq(1)
  end

  it "executes rescue if something is raised unconditionally" do
    y = 1
    x = 1
    x = begin
          raise "Oh no!"
          y = 2
        rescue
          3
        end
    x.should eq(3)
    y.should eq(1)
  end
end
