require 'spec_helper'

describe 'Code gen: global' do
  it "codegens global" do
    run("$foo = 1; def foo; $foo = 2.5; end; foo; $foo").to_f.should eq(2.5)
  end
end
