require 'spec_helper'

describe 'Code gen: union type' do
  it "codegens union type when obj is union and no args" do
    run("a = 1; a = 2.5; a.to_f").to_f.should eq(2.5)
  end

  it "codegens union type when obj is union and arg is union" do
    run("a = 1; a = 1.5; (a + a).to_f").to_f.should eq(3)
  end

  it "codegens union type when obj is not union but arg is" do
    run("a = 1; b = 2; b = 1.5; (a + b).to_f").to_f.should eq(2.5)
  end

  it "codegens union type when obj union but arg is not" do
    run("a = 1; b = 2; b = 1.5; (b + a).to_f").to_f.should eq(2.5)
  end

  it "codegens union type when no obj" do
    run("def foo(x); x; end; a = 1; a = 2.5; foo(a).to_f").to_f.should eq(2.5)
  end

  it "codegens union type as return value" do
    run("def foo; a = 1; a = 2.5; a; end; foo.to_f").to_f.should eq(2.5)
  end

  it "codegens union type for instance var" do
    run(%Q(
      class Foo
        #{rw :value}
      end

      f = Foo.new
      f.value = 1
      f.value = 1.5
      (f.value + f.value).to_f
    )).to_f.should eq(3)
  end

  it "codegens if with same nested union" do
    run(%Q(
      if true
        if true
          1
        else
          2.5
        end
      else
        if true
          1
        else
          2.5
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
      f.foo 2.5
      f.x.to_f
      )).to_f.should eq(2.5)
  end
end
