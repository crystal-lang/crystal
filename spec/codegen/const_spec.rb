require 'spec_helper'

describe 'Codegen: const' do
  it "define a constant" do
    run("A = 1; A").to_i.should eq(1)
  end

  it "types a nested constant" do
    run("class B; A = 1; end; B::A").to_i.should eq(1)
  end
end
