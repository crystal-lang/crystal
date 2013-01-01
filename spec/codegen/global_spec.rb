require 'spec_helper'

describe 'Code gen: global' do
  it "codegens global" do
    run("$foo = 1; def foo; $foo = 2; end; foo; $foo").to_i.should eq(2)
  end

  it "codegens global with union" do
    run("$foo = 1; def foo; $foo = 2.5f; end; foo; $foo.to_f").to_f.should eq(2.5)
  end
end
