require "spec"
require "crypto/subtle"

describe "Subtle" do
  it "compares constant times" do
    data = [
      {"a" => Slice.new(1, 0x11), "b" => Slice.new(1, 0x11), "result" => true},
      {"a" => Slice.new(1, 0x12), "b" => Slice.new(1, 0x11), "result" => false},
      {"a" => Slice.new(1, 0x11), "b" => Slice.new(2) { |i| 0x11 + i }, "result" => false},
      {"a" => Slice.new(2) { |i| 0x11 + i }, "b" => Slice.new(1, 0x11), "result" => false},
    ]

    data.each do |test|
      Crypto::Subtle.constant_time_compare(test["a"].as(Slice(Int32)), test["b"].as(Slice(Int32))).should eq(test["result"])
    end
  end

  it "compares constant time bytes on equality" do
    data = [
      {"a" => 0x00_u8, "b" => 0x00_u8, "result" => 1},
      {"a" => 0x00_u8, "b" => 0x01_u8, "result" => 0},
      {"a" => 0x01_u8, "b" => 0x00_u8, "result" => 0},
      {"a" => 0xff_u8, "b" => 0xff_u8, "result" => 1},
      {"a" => 0xff_u8, "b" => 0xfe_u8, "result" => 0},
    ]

    data.each do |test|
      Crypto::Subtle.constant_time_byte_eq(test["a"], test["b"]).should eq(test["result"])
    end
  end

  it "compares constant time bytes bug" do
    h1 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOa9lH9zigNKnksVaDwViFNgPU4WkrD53J"
    h2 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOaHlSGFuDDwMuVg6gOzdxQ0xN4rFOwMUn"
    Crypto::Subtle.constant_time_compare(h1, h2).should eq(false)
  end

  it "compares constant time and slices strings" do
    h1 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOa9lH9zigNKnksVaDwViFNgPU4WkrD53J"
    h2 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOaHlSGFuDDwMuVg6gOzdxQ0xN4rFOwMUn"

    slice_result = Crypto::Subtle.constant_time_compare(h1.to_slice, h2.to_slice)
    Crypto::Subtle.constant_time_compare(h1, h2).should eq(slice_result)
  end
end
