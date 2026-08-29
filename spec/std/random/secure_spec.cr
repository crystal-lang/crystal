require "spec"
require "random/secure"

describe "Random::Secure" do
  it "returns random number from a secure system source" do
    Random::Secure.next_u.should be_a(Int::Unsigned)

    x = Random::Secure.rand(123456...654321)
    x.should be >= 123456
    x.should be < 654321

    Random::Secure.rand(Int64::MAX // 2).should be <= (Int64::MAX // 2)
  end

  it "fully fills a large buffer" do
    # mostly testing the linux getrandom calls
    bytes = Random::Secure.random_bytes(10000)
    bytes[9990, 10].should_not eq(Bytes.new(10))
  end

  it "returns a random integer in range (#8219)" do
    {% for type in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Int128 UInt128).map(&.id) %}
      value = Random::Secure.rand({{ type }}::MIN..{{ type }}::MAX)
      typeof(value).should eq({{ type }})
    {% end %}
  end
end
