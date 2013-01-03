require 'spec_helper'

describe 'Codegen: is_a?' do
  it "codegens is_a? true for simple type" do
    run("1.is_a?(Int)").to_b.should be_true
  end

  it "codegens is_a? false for simple type" do
    run("1.is_a?(Bool)").to_b.should be_false
  end
end
