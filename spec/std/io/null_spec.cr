require "spec"

describe IO::Null do
  it "#read" do
    slice = Bytes.new(10, 1_u8)
    io = IO::Null.new

    io.read(slice).should eq(0)
    slice.each { |byte| byte.should eq(1_u8) }
  end

  it "#write" do
    io = IO::Null.new
    io.write Bytes.new(10)
  end
end
