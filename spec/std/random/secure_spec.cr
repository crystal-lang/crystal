require "spec"
require "random/secure"

describe "Random::Secure" do
  it "returns random number from a secure system source" do
    Random::Secure.next_u.should be_a(Int::Unsigned)

    x = Random::Secure.rand(123456...654321)
    x.should be >= 123456
    x.should be < 654321

    Random::Secure.rand(Int64::MAX / 2).should be <= (Int64::MAX / 2)
  end

  it "fully fills a large buffer" do
    # mostly testing the linux getrandom calls
    bytes = Random::Secure.random_bytes(10000)
    bytes[9990, 10].should_not eq(Bytes.new(10))
  end
end
