require 'spec_helper'

describe 'Code gen: def' do
  it "codegens call without args" do
    run('def foo; 1; end; 2; foo').to_i.should eq(1)
  end

  it "call functions defined in any order" do
    run('def foo; bar; end; def bar; 1; end; foo').to_i.should eq(1)
  end

  it "codegens call with args" do
    run('def foo(x); x; end; foo 1').to_i.should eq(1)
  end

  it "call external function 'putchar'" do
    run("putchar '\\0'").to_i.should eq(0)
  end

  it "uses self" do
    run("class Int; def foo; self + 1; end; end; 3.foo").to_i.should eq(4)
  end

  it "uses var after external" do
    run("a = 1; putchar '\\0'; a").to_i.should eq(1)
  end

  it "allows to change argument values" do
    run("def foo(x); x = 1; x; end; foo(2)").to_i.should eq(1)
  end

  it "runs empty def" do
    run("def foo; end; foo")
  end

  it "builds infinite recursive function" do
    node = parse "def foo; foo; end; foo"
    mod = infer_type node
    build node, mod
  end

  it "includes return type in the mangled name" do
    run(%Q(
      class Foo
        #{rw :value}
      end

      def gen
        Foo.new
      end

      f = gen
      f.value = 1

      g = gen
      g.value = 2.5

      f.value + g.value
    )).to_f.should eq(3.5)
  end
end
