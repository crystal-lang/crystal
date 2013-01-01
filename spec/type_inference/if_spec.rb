require 'spec_helper'

describe 'Type inference: if' do
  it "types an if without else" do
    assert_type('if true; 1; end') { UnionType.new(int, self.nil) }
  end

  it "types an if with else of same type" do
    assert_type('if true; 1; else; 2; end') { int }
  end

  it "types an if with else of different type" do
    assert_type('if true; 1; else; 1.1; end') { UnionType.new(int, double) }
  end
end