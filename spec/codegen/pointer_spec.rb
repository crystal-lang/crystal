require 'spec_helper'

describe 'Code gen: pointer' do
  it "get pointer and value of it" do
    run('a = 1; b = ptr(a); b.value').to_i.should eq(1)
  end
end