require 'spec_helper'

describe 'Code gen: array' do
  it "codegens array length" do
    run('a = [1, 2]; a.length').to_i.should eq(2)
  end

  it "codegens array get" do
    run('a = [1, 2]; a[0]').to_i.should eq(1)
  end

  it "codegens array set" do
    run('a = [1, 2]; a[1] = 3; a[1]').to_i.should eq(3)
  end

  it "codegens array set and get with union" do
    run('a = [0, 0]; a[0] = 1; a[1] = 1.5; a[0].to_i').to_i.should eq(1)
  end

  it "codegens array push" do
    run('a = []; a << 1; a << 2; a[0] + a[1]').to_i.should eq(3)
  end

  it "realloc array buffer when pushing" do
    run('a = []; j = 0; while j < 10000; a << 1; j += 1; end')
  end

  it "codegens an empty array" do
    run('a = []; a.length').to_i.should eq(0)
  end

  it "codegens Array new with lengrh" do
    run('a = Array.new(10, 1); a.length').to_i.should eq(10)
  end

  it "codegens Array new with int getter" do
    run('a = Array.new(10, 1); a[9]').to_i.should eq(1)
  end

  it "codegens Array new with float getter" do
    run('a = Array.new(10, 2.5); a[9]').to_f.should eq(2.5)
  end

  it "codegens recursive array" do
    run('a = []; a << a; a.length').to_i.should eq(1)
  end

  it "codegens array set in recursive union" do
    run('a = [0] ; a[0] = a; a.length').to_i.should eq(1)
  end
end
