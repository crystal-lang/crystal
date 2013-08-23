require "../../spec_helper"

describe "Code gen: var" do
  it "codegens var" do
    run("a = 1; 1.5; a").to_i.should eq(1)
  end
end
