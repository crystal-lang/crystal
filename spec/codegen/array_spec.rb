require 'spec_helper'

describe 'Code gen: array' do
  it "codegens array length" do
    run('require "array"; a = [1, 2]; a.length').to_i.should eq(2)
  end

  it "codegens array get" do
    run('require "array"; a = [1, 2]; a[0]').to_i.should eq(1)
  end

  it "codegens array set" do
    run('require "array"; a = [1, 2]; a[1] = 3; a[1]').to_i.should eq(3)
  end

  it "codegens array push" do
    run('require "array"; a = Array(Int).new; a << 1; a << 2; a[0] + a[1]').to_i.should eq(3)
  end

  it "realloc array buffer when pushing" do
    run('require "array"; a = Array(Int).new; j = 0; while j < 10000; a << 1; j += 1; end')
  end

  it "codegens an empty array" do
    run('require "array"; a = Array(Int).new; a.length').to_i.should eq(0)
  end

  it "codegens method with array mutation" do
    run('require "array"; def foo(x); end; a = Array(Int).new; foo a; a.push(1)')
  end

  it "codegens method with array mutation and while" do
    run('require "array"; def foo(x); while false; end; end; a = Array(Int).new; foo a; a.push(1)')
  end

  it "codegens empty array loop" do
    run('require "array"; def bar(x); end; a = Array(Int).new; i = 0; while i < a.length; bar a[i]; i += 1; end')
  end
end
