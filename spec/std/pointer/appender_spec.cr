require "spec"

describe Pointer::Appender do
  it ".new" do
    Pointer::Appender.new(Pointer(Void).null)
  end

  it "#<<" do
    data = Slice(Int32).new(5)
    appender = data.to_unsafe.appender
    4.times do |i|
      appender << (i + 1) * 2
    end

    data.should eq Slice[2, 4, 6, 8, 0]
  end

  it "#size" do
    data = Slice(Int32).new(5)
    appender = data.to_unsafe.appender
    appender.size.should eq 0
    4.times do |i|
      appender << 0
      appender.size.should eq i + 1
    end
    appender.size.should eq 4
  end

  it "#to_slice" do
    data = Slice(Int32).new(5)
    appender = data.to_unsafe.appender
    appender.to_slice.should eq Slice(Int32).new(0)
    appender.to_slice.to_unsafe.should eq data.to_unsafe

    4.times do |i|
      appender << (i + 1) * 2
      appender.to_slice.should eq data[0, i + 1]
    end
    appender.to_slice.should eq Slice[2, 4, 6, 8]
    appender.to_slice.to_unsafe.should eq data.to_unsafe
  end
end
