require "spec"
require "crypto/subtle"

describe "Subtle" do
  it "compares constant times" do
    Crypto::Subtle.constant_time_compare(Slice.new(1, 0x11), Slice.new(1, 0x11)).should be_true
    Crypto::Subtle.constant_time_compare(Slice.new(1, 0x12), Slice.new(1, 0x11)).should be_false
    Crypto::Subtle.constant_time_compare(Slice.new(1, 0x11), Slice.new(2) { |i| 0x11 + i }).should be_false
    Crypto::Subtle.constant_time_compare(Slice.new(2) { |i| 0x11 + i }, Slice.new(1, 0x11)).should be_false
  end

  it "compares constant time bytes on equality" do
    Crypto::Subtle.constant_time_byte_eq(0x00_u8, 0x00_u8).should eq 1_u8
    Crypto::Subtle.constant_time_byte_eq(0x00_u8, 0x01_u8).should eq 0_u8
    Crypto::Subtle.constant_time_byte_eq(0x01_u8, 0x00_u8).should eq 0_u8
    Crypto::Subtle.constant_time_byte_eq(0xff_u8, 0xff_u8).should eq 1_u8
    Crypto::Subtle.constant_time_byte_eq(0xff_u8, 0xfe_u8).should eq 0_u8
  end

  it "compares constant time bytes bug" do
    h1 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOa9lH9zigNKnksVaDwViFNgPU4WkrD53J"
    h2 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOaHlSGFuDDwMuVg6gOzdxQ0xN4rFOwMUn"
    Crypto::Subtle.constant_time_compare(h1, h2).should be_false
  end

  it "compares constant time and slices strings" do
    h1 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOa9lH9zigNKnksVaDwViFNgPU4WkrD53J"
    h2 = "$2a$05$LEC1XBXgXECzKUO2LBDhKOaHlSGFuDDwMuVg6gOzdxQ0xN4rFOwMUn"

    slice_result = Crypto::Subtle.constant_time_compare(h1.to_slice, h2.to_slice)
    Crypto::Subtle.constant_time_compare(h1, h2).should eq(slice_result)
  end
end
