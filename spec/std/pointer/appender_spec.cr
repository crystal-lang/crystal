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
    appender.size.should eq 4

    data.should eq Slice[2, 4, 6, 8, 0]
  end

  it "#size" do
    data = Slice(Int32).new(5)
    appender = data.to_unsafe.appender
    appender.size.should eq 0
    4.times do |i|
      appender << 0
    end
    appender.size.should eq 4
  end
end
