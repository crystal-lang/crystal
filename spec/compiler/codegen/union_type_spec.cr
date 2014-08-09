#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: union type" do
  it "codegens union type when obj is union and no args" do
    run("a = 1; a = 2.5_f32; a.to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when obj is union and arg is union" do
    run("a = 1; a = 1.5_f32; (a + a).to_f").to_f64.should eq(3)
  end

  it "codegens union type when obj is not union but arg is" do
    run("a = 1; b = 2; b = 1.5_f32; (a + b).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when obj union but arg is not" do
    run("a = 1; b = 2; b = 1.5_f32; (b + a).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when no obj" do
    run("def foo(x); x; end; a = 1; a = 2.5_f32; foo(a).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when no obj and restrictions" do
    run("def foo(x : Int); 1.5; end; def foo(x : Float); 2.5; end; a = 1; a = 3.5_f32; foo(a).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type as return value" do
    run("def foo; a = 1; a = 2.5_f32; a; end; foo.to_f").to_f64.should eq(2.5)
  end

  it "codegens union type for instance var" do
    run("
      class Foo
        def initialize(value)
          @value = value
        end
        def value=(@value); end
        def value; @value; end
      end

      f = Foo.new(1)
      f.value = 1.5_f32
      (f.value + f.value).to_f
    ").to_f64.should eq(3)
  end

  it "codegens if with same nested union" do
    run("
      if true
        if true
          1
        else
          2.5_f32
        end
      else
        if true
          1
        else
          2.5_f32
        end
      end.to_i
    ").to_i.should eq(1)
  end

  it "assigns union to union" do
    run("
      require \"prelude\"

      struct Char
        def to_i
          ord
        end
      end

      class Foo
        def foo(x)
          @x = x
          @x = @x || 1
        end

        def x
          @x
        end
      end

      f = Foo.new
      f.foo 1
      f.foo 'a'
      f.x.to_i
      ").to_i.should eq(97)
  end

  it "assigns union to larger union" do
    run("
      require \"prelude\"
      a = 1
      a = 1.1_f32
      b = \"c\"
      b = 'd'
      a = b
      a.to_s
    ").to_string.should eq("d")
  end

  it "assigns union to larger union when source is nilable 1" do
    value = run("
      require \"prelude\"
      a = 1
      b = nil
      b = Reference.new
      a = b
      a.to_s
    ").to_string
    value.includes?("Reference").should be_true
  end

  it "assigns union to larger union when source is nilable 2" do
    run("
      require \"prelude\"
      a = 1
      b = Reference.new
      b = nil
      a = b
      a.to_s
    ").to_string.should eq("")
  end

  it "dispatch call to object method on nilable" do
    run("
      require \"prelude\"
      class Foo
      end

      a = nil
      a = Foo.new
      a.nil?
    ")
  end
end
