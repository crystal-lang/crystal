require 'spec_helper'

describe 'Code gen: return' do
  it "codegens return" do
    run('def foo; return 1; end; foo').to_i.should eq(1)
  end

  it "codegens return followed by another expression" do
    run('def foo; return 1; 2; end; foo').to_i.should eq(1)
  end

  it "codegens return inside if" do
    run('def foo; if true; return 1; end; 2; end; foo').to_i.should eq(1)
  end
end
