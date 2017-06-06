require "spec"
require "random/system"

describe "Random::System" do
  rng = Random::System.new

  it "returns random number from the secure system source" do
    rng.next_u.should be_a(Int::Unsigned)

    x = rng.rand(123456...654321)
    x.should be >= 123456
    x.should be < 654321

    rng.rand(Int64::MAX / 2).should be <= (Int64::MAX / 2)
  end
end
