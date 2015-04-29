require "spec"

describe String::Builder do
  it "builds" do
    str = String::Builder.build do |builder|
      builder << 123
      builder << 456
    end
    str.should eq("123456")
    str.length.should eq(6)
    str.bytesize.should eq(6)
  end

  it "raises if invokes to_s twice" do
    builder = String::Builder.new
    builder << 123
    builder.to_s.should eq("123")

    expect_raises { builder.to_s }
  end
end
