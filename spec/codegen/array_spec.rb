require 'spec_helper'

describe 'Code gen: array' do
  it "codegens array length" do
    run('a = [1, 2]; a.length', load_std: ['pointer', 'array']).to_i.should eq(2)
  end

  it "codegens array get" do
    run('a = [1, 2]; a[0]', load_std: ['pointer', 'array']).to_i.should eq(1)
  end

  it "codegens array set" do
    run('a = [1, 2]; a[1] = 3; a[1]', load_std: ['pointer', 'array']).to_i.should eq(3)
  end

  it "codegens array push" do
    run('a = []; a << 1; a << 2; a[0] + a[1]', load_std: ['pointer', 'array']).to_i.should eq(3)
  end

  it "realloc array buffer when pushing" do
    run('a = []; j = 0; while j < 10000; a << 1; j += 1; end', load_std: ['pointer', 'array'])
  end

  it "codegens an empty array" do
    run('a = []; a.length', load_std: ['pointer', 'array']).to_i.should eq(0)
  end

  it "codegens recursive array" do
    run('a = []; a << a; a.length', load_std: ['pointer', 'array']).to_i.should eq(1)
  end

  it "codegens array set in recursive union" do
    run('a = [0] ; a[0] = a; a.length', load_std: ['pointer', 'array']).to_i.should eq(1)
  end

  it "codegens method with array mutation" do
    run('def foo(x); end; a = []; foo a; a.push(1)', load_std: ['pointer', 'array'])
  end

  it "codegens method with array mutation and while" do
    run('def foo(x); while false; end; end; a = []; foo a; a.push(1)', load_std: ['pointer', 'array'])
  end

  it "codegens empty array loop" do
    run('def bar(x); end; a = []; i = 0; while i < a.length; bar a[i]; i += 1; end', load_std: ['pointer', 'array'])
  end
end
