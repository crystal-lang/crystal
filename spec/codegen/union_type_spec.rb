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
end
