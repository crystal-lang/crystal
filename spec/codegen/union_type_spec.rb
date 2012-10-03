require 'spec_helper'

describe 'Code gen: union type' do
  it "codegens union type when obj is union" do
    run("a = 1; a = 2.5; a.to_f").to_f.should eq(2.5)
  end

  it "codegens union type when obj is union and arg is union" do
    run("a = 1; a = 1.5; (a + a).to_f").to_f.should eq(3)
  end
end
