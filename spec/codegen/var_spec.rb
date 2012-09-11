require 'spec_helper'

describe 'Code gen: var' do
  it 'codegens var' do
    run('a = 1; 1.5; a').to_i.should eq(1)
  end

  it 'codegens var with same name but different type' do
    run('a = 1; a = 2.5; a').to_f.should eq(2.5)
  end
end
