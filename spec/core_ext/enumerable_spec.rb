require 'spec_helper'

describe Enumerable do
  it "gets element at position" do
    [1, 2, 3].at(1).should eq(2)
  end
end