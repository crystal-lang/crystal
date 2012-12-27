require 'spec_helper'

describe 'Codegen: while' do
  it "codegens def with while" do
    run('def foo; while false; 1; end; end; foo')
  end

  it "codegens while with false" do
    run('a = 1; while false; a = 2; end; a').to_i.should eq(1)
  end

  it "codegens while with non-false condition" do
    run('a = 1; while a < 10; a = a + 1; end; a').to_i.should eq(10)
  end

  it "codegens while as modifier" do
    run('a = 1; begin; a += 1; end while false; a').to_i.should eq(2)
  end
end