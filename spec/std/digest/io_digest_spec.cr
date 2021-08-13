require "spec"
require "digest"

describe IO::Digest do
  it "calculates digest from reading" do
    base_io = IO::Memory.new("foo")
    io = IO::Digest.new(base_io, ::Digest::SHA256.new)
    slice = Bytes.new(256)
    io.read(slice).should eq(3)

    slice[0, 3].should eq("foo".to_slice)
    io.final.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "can be created with ongoing digest" do
    base_digest = OpenSSL::Digest.new("SHA256")
    base_digest.update("foo")

    base_io = IO::Memory.new("bar")
    io = IO::Digest.new(base_io, base_digest)
    slice = Bytes.new(256)
    io.read(slice).should eq(3)

    base_digest.update("baz")

    # sha256("foobarbaz")
    io.final.should eq("97df3588b5a3f24babc3851b372f0ba71a9dcdded43b14b9d06961bfc1707d9d".hexbytes)
  end

  it "calculates digest from multiple reads" do
    base_io = IO::Memory.new("foo")
    base_digest = OpenSSL::Digest.new("SHA256")
    io = IO::Digest.new(base_io, base_digest)
    slice = Bytes.new(2)
    io.read(slice).should eq(2)
    slice[0, 2].should eq("fo".to_slice)

    io.read(slice).should eq(1)
    slice[0, 1].should eq("o".to_slice)

    io.final.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "does not calculate digest on read" do
    base_io = IO::Memory.new("foo")
    base_digest = OpenSSL::Digest.new("SHA256")
    empty_digest = OpenSSL::Digest.new("SHA256").final
    io = IO::Digest.new(base_io, base_digest, IO::Digest::DigestMode::Write)
    slice = Bytes.new(256)
    io.read(slice).should eq(3)
    slice[0, 3].should eq("foo".to_slice)
    io.final.should eq(empty_digest)
  end

  it "calculates digest from writing" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    io = IO::Digest.new(base_io, base_digest, IO::Digest::DigestMode::Write)
    io.write("foo".to_slice)

    base_io.to_slice[0, 3].should eq("foo".to_slice)
    io.final.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "calculates digest from writing a string" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    io = IO::Digest.new(base_io, base_digest, IO::Digest::DigestMode::Write)
    io.print("foo")

    base_io.to_slice[0, 3].should eq("foo".to_slice)
    io.final.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "calculates digest from multiple writes" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    io = IO::Digest.new(base_io, base_digest, IO::Digest::DigestMode::Write)
    io.write("fo".to_slice)
    io.write("o".to_slice)
    base_io.to_slice[0, 3].should eq("foo".to_slice)

    io.final.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "does not calculate digest on write" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    empty_digest = OpenSSL::Digest.new("SHA256").final
    io = IO::Digest.new(base_io, base_digest, IO::Digest::DigestMode::Read)
    io.write("foo".to_slice)

    base_io.to_slice[0, 3].should eq("foo".to_slice)
    io.final.should eq(empty_digest)
  end
end
