require 'spec_helper'

describe 'Codegen: while' do
  it "codegens while with false" do
    run('a = 1; while false; a = 2; end; a').to_i.should eq(1)
  end

  it "codegens while with non-false condition" do
    run('a = 1; while a < 10; a = a + 1; end; a').to_i.should eq(10)
  end
end