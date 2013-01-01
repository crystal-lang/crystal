require 'spec_helper'

describe 'Code gen: multi assign' do
  it "codegens multi assign first expression" do
    run('a, b = 1, 2.5; a').to_i.should eq(1)
  end

  it "codegens multi assign second expression" do
    run('a, b = 1, 2.5; b').to_f.should eq(2.5)
  end
end
