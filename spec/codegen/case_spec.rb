require 'spec_helper'

describe 'Code gen: case' do
  it "codegens case with one condition" do
    run('require "object"; case 1; when 1; 2; else; 3; end').to_i.should eq(2)
  end

  it "codegens case with two conditions" do
    run('require "object"; case 1; when 0, 1; 2; else; 3; end').to_i.should eq(2)
  end

  it "codegens case with else" do
    run('require "object"; case 1; when 0; 2; else; 3; end').to_i.should eq(3)
  end
end
