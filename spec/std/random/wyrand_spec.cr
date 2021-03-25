require "spec"
require "random/wyrand"

describe Random::Wyrand do
  # There does not appear to be a spec by the original implementor. The
  # following are pulled from the Swift implementation by one of the co-authors.
  # https://github.com/lemire/SwiftWyhash/blob/3183bb1f473d7da2e7b6f856bad56a8aab3a56fa/Tests/SwiftWyhashTests/SwiftWyhashTests.swift#L6-L9
  it "generates outputs expected for a known seed" do
    seed = 42_u64
    outs = {12558987674375533620, 16846851108956068306, 14652274819296609082}
    gen = Random::Wyrand.new seed
    outs.each do |expected|
      gen.next_u.should eq(expected)
    end
  end

  it "can be initialized without an explicit seed" do
    Random::Wyrand.new.should be_a Random::Wyrand
  end

  it "generates ranged values within the upper bound" do
    gen = Random::Wyrand.new
    {% for size in [8, 16, 32, 64] %}
      {% type = "UInt#{size}".id %}
      1_000.times do
        max = gen.rand {{type}}::MIN.succ..{{type}}::MAX
        1_000.times do
          (gen.rand(max) < max).should be_true
        end
      end
    {% end %}
  end
end
