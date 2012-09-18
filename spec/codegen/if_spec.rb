require 'spec_helper'

describe 'Code gen: if' do
  it 'codegens if without an else with true' do
    run('a = 1; if true; a = 2; end; a').to_i.should eq(2)
  end

  it 'codegens if without an else with false' do
    run('a = 1; if false; a = 2; end; a').to_i.should eq(1)
  end

  it 'codegens if inside def without an else with true' do
    run('def foo; a = 1; if true; a = 2; end; a; end; foo').to_i.should eq(2)
  end
end
