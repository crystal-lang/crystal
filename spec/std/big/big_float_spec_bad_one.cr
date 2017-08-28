require "spec"
require "big"

describe "BigFloat" do
  it "initialize(BigRational)" do
    expect_raises do
      BigFloat.new( BigRational.new(1, 1) )
    end
  end
end

