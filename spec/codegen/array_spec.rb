require 'spec_helper'

describe 'Code gen: array' do
  it "codegens array length" do
    run('require "pointer"; require "array"; a = [1, 2]; a.length').to_i.should eq(2)
  end

  it "codegens array get" do
    run('require "pointer"; require "array"; a = [1, 2]; a[0]').to_i.should eq(1)
  end

  it "codegens array set" do
    run('require "pointer"; require "array"; a = [1, 2]; a[1] = 3; a[1]').to_i.should eq(3)
  end

  it "codegens array push" do
    run('require "pointer"; require "array"; a = []; a << 1; a << 2; a[0] + a[1]').to_i.should eq(3)
  end

  it "realloc array buffer when pushing" do
    run('require "pointer"; require "array"; a = []; j = 0; while j < 10000; a << 1; j += 1; end')
  end

  it "codegens an empty array" do
    run('require "pointer"; require "array"; a = []; a.length').to_i.should eq(0)
  end

  it "codegens recursive array" do
    run('require "pointer"; require "array"; a = []; a << a; a.length').to_i.should eq(1)
  end

  it "codegens array set in recursive union" do
    run('require "pointer"; require "array"; a = [0] ; a[0] = a; a.length').to_i.should eq(1)
  end

  it "codegens method with array mutation" do
    run('require "pointer"; require "array"; def foo(x); end; a = []; foo a; a.push(1)')
  end

  it "codegens method with array mutation and while" do
    run('require "pointer"; require "array"; def foo(x); while false; end; end; a = []; foo a; a.push(1)')
  end

  it "codegens empty array loop" do
    run('require "pointer"; require "array"; def bar(x); end; a = []; i = 0; while i < a.length; bar a[i]; i += 1; end')
  end

  it "inspects array" do
    run('require "object"; require "int"; require "string"; require "enumerable"; require "pointer"; require "array"; [1, 2, 3].inspect').to_string.should eq('[1, 2, 3]')
  end
end
