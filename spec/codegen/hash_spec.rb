require 'spec_helper'

describe 'Code gen: hash' do
  it "codegens hash length" do
    run('require "hash"; a = {}; a.length').to_i.should eq(0)
  end

  it "codegens hash set/get" do
    run('require "prelude"; a = {}; a[1] = 2; a[1].to_i').to_i.should eq(2)
  end

  it "codegens hash get" do
    run('require "prelude"; a = {1 => 2}; a[1].to_i').to_i.should eq(2)
  end

  it "codegens hash with union keys and values" do
    run('require "prelude"; a = {1 => 2, :foo => 1.1}; a[1].to_i').to_i.should eq(2)
  end
end