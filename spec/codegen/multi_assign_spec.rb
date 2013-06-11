require 'spec_helper'

describe 'Code gen: multi assign' do
  it "codegens multi assign first expression" do
    run('a, b = 1, 2.5_f32; a').to_i.should eq(1)
  end

  it "codegens multi assign second expression" do
    run('a, b = 1, 2.5_f32; b').to_f.should eq(2.5)
  end

  it "codegens swap first expression" do
    run('a, b = 1, 2; a, b = b, a; a').to_i.should eq(2)
  end

  it "codegens swap second expression" do
    run('a, b = 1, 2; a, b = b, a; b').to_i.should eq(1)
  end
end
