require 'spec_helper'

describe 'Code gen: fun' do
  it "call simple fun literal" do
    run("x = -> { 1 }; x.call").to_i.should eq(1)
  end
end
