#!/usr/bin/env bin/crystal -run
require "spec"

describe "Exception" do
  it "executes body if nothing raised" do
    y = 1
    x = begin
          1
        rescue
          y = 2
        end
    x.should eq(1)
    y.should eq(1)
  end

  it "executes rescue if something is raised conditionally" do
    y = 1
    x = 1
    x = begin
          y == 1 ? raise "Oh no!" : nil
          y = 2
        rescue
          y = 3
        end
    x.should eq(3)
    y.should eq(3)
  end

  it "executes rescue if something is raised unconditionally" do
    y = 1
    x = 1
    x = begin
          raise "Oh no!"
          y = 2
        rescue
          y = 3
        end
    x.should eq(3)
    y.should eq(3)
  end

  it "can result into union" do
    x = begin
      1
    rescue
      1.1
    end

    x.should eq(1)

    y = begin
      1 > 0 ? raise "Oh no!" : 0
    rescue
      1.1
    end

    y.should eq(1.1)
  end

  it "handles nested exceptions" do
    a = 0
    b = begin
      begin
        raise "Oh no!"
      rescue
        a = 1
        raise "Boom!"
      end
    rescue
      2
    end

    a.should eq(1)
    b.should eq(2)
  end

  it "executes ensure when no exception is raised" do
    a = 0
    b = begin
          a = 1
        rescue
          a = 3
        ensure
          a = 2
        end
    a.should eq(2)
    b.should eq(1)
  end

  it "executes ensure when exception is raised" do
    a = 0
    b = begin
          a = 1
          raise "Oh no!"
        rescue
          a = 3
        ensure
          a = 2
        end
    a.should eq(2)
    b.should eq(3)
  end

  class Ex1 < Exception
  end

  class Ex2 < Exception
  end

  it "rescue with type" do
    a = begin
      raise Ex2.new
    rescue Ex1
      1
    rescue Ex2
      2
    end

    a.should eq(2)
  end

  it "rescue with types defaults to generic rescue" do
    a = begin
      raise "Oh no!"
    rescue Ex1
      1
    rescue Ex2
      2
    rescue
      3
    end

    a.should eq(3)
  end

  it "handle exception in outer block" do
    p = 0
    x = begin
      begin
        raise Ex1.new
      rescue Ex2
        p = 1
        1
      end
    rescue
      2
    end

    x.should eq(2)
    p.should eq(0)
  end
end
