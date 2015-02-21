require "spec"
require "crypto/subtle"

describe "Subtle" do
  it "compares constant times" do
    data = [
      {"a" => Slice.new(1, 0x11), "b" => Slice.new(1, 0x11), "result" => 1},
      {"a" => Slice.new(1, 0x12), "b" => Slice.new(1, 0x11), "result" => 0},
      {"a" => Slice.new(21, 0x11), "b" => Slice.new(2) { |i| 0x11 + i }, "result" => 0},
      {"a" => Slice.new(2) { |i| 0x11 + i }, "b" => Slice.new(1, 0x11), "result" => 0},
    ]

    data.each do |test|
      Crypto::Subtle.constant_time_compare(test["a"] as Slice(Int32), test["b"] as Slice(Int32)).should eq(test["result"])
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
end