require 'spec_helper'

describe 'Code gen: union type' do
  it "codegens union type when obj is union and no args" do
    run("a = 1; a = 2.5f; a.to_f").to_f.should eq(2.5)
  end

  it "codegens union type when obj is union and arg is union" do
    run("a = 1; a = 1.5f; (a + a).to_f").to_f.should eq(3)
  end

  it "codegens union type when obj is not union but arg is" do
    run("a = 1; b = 2; b = 1.5f; (a + b).to_f").to_f.should eq(2.5)
  end

  it "codegens union type when obj union but arg is not" do
    run("a = 1; b = 2; b = 1.5f; (b + a).to_f").to_f.should eq(2.5)
  end

  it "codegens union type when no obj" do
    run("def foo(x); x; end; a = 1; a = 2.5f; foo(a).to_f").to_f.should eq(2.5)
  end

  it "codegens union type as return value" do
    run("def foo; a = 1; a = 2.5f; a; end; foo.to_f").to_f.should eq(2.5)
  end

  it "codegens union type for instance var" do
    run(%Q(
      class Foo
        #{rw :value}
      end

      f = Foo.new
      f.value = 1
      f.value = 1.5f
      (f.value + f.value).to_f
    )).to_f.should eq(3)
  end

  it "codegens if with same nested union" do
    run(%Q(
      if true
        if true
          1
        else
          2.5f
        end
      else
        if true
          1
        else
          2.5f
        end
      end.to_i
    )).to_i.should eq(1)
  end

  it "assigns union to union" do
    run(%Q(
      class Foo
        def foo(x)
          @x = x
          @x = @x
        end

        def x
          @x
        end
      end

      f = Foo.new
      f.foo 1
      f.foo 2.5f
      f.x.to_f
      )).to_f.should eq(2.5)
  end

  it "assigns union to larger union" do
    run(%q(
      require "prelude"
      a = 1
      a = 1.1f
      b = "c"
      b = 'd'
      a = b
      a.to_s
    )).to_string.should eq("d")
  end

  it "assigns union to larger union when source is nilable 1" do
    run(%q(
      require "prelude"
      a = 1
      b = nil
      b = Object.new
      a = b
      a.to_s
    )).to_string.should =~ /Object/
  end

  it "assigns union to larger union when source is nilable 2" do
    run(%q(
      require "prelude"
      a = 1
      b = Object.new
      b = nil
      a = b
      a.to_s
    )).to_string.should eq("")
  end

  it "codegens int, empty array and int array union" do
    run(%q(
      require "prelude"
      a = 1
      a = []
      a = []
      a << 1
      ))
  end
end
