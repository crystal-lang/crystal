require 'spec_helper'

describe 'Code gen: hash' do
  it "codegens hash length" do
    run('a = {}; a.length', load_std: ['pointer', 'int', 'array', 'hash']).to_i.should eq(0)
  end

  it "codegens hash set/get" do
    run('a = {}; a[1] = 2; a[1].to_i', load_std: ['pointer', 'nil', 'int', 'array', 'hash']).to_i.should eq(2)
  end

  it "codegens hash get" do
    run('a = {1 => 2}; a[1].to_i', load_std: ['pointer', 'nil', 'int', 'array', 'hash']).to_i.should eq(2)
  end
end