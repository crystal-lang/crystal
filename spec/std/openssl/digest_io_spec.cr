require "spec"
require "../../../src/openssl"

describe OpenSSL::DigestIO do
  it "calculates digest from reading" do
    base_io = IO::Memory.new("foo")
    base_digest = OpenSSL::Digest.new("SHA256")
    io = OpenSSL::DigestIO.new(base_io, base_digest)
    slice = Bytes.new(256)
    io.read(slice).should eq(3)

    slice[0, 3].should eq("foo".to_slice)
    io.digest.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "calculates digest from multiple reads" do
    base_io = IO::Memory.new("foo")
    base_digest = OpenSSL::Digest.new("SHA256")
    io = OpenSSL::DigestIO.new(base_io, base_digest)
    slice = Bytes.new(2)
    io.read(slice).should eq(2)
    slice[0, 2].should eq("fo".to_slice)

    io.read(slice).should eq(1)
    slice[0, 1].should eq("o".to_slice)

    io.digest.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "does not calculate digest on read" do
    base_io = IO::Memory.new("foo")
    base_digest = OpenSSL::Digest.new("SHA256")
    empty_digest = OpenSSL::Digest.new("SHA256").digest
    io = OpenSSL::DigestIO.new(base_io, base_digest, OpenSSL::DigestIO::DigestMode::Write)
    slice = Bytes.new(256)
    io.read(slice).should eq(3)
    slice[0, 3].should eq("foo".to_slice)
    io.digest.should eq(empty_digest)
  end

  it "calculates digest from writing" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    io = OpenSSL::DigestIO.new(base_io, base_digest, OpenSSL::DigestIO::DigestMode::Write)
    io.write("foo".to_slice)

    base_io.to_slice[0, 3].should eq("foo".to_slice)
    io.digest.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "calculates digest from writing a string" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    io = OpenSSL::DigestIO.new(base_io, base_digest, OpenSSL::DigestIO::DigestMode::Write)
    io.print("foo")

    base_io.to_slice[0, 3].should eq("foo".to_slice)
    io.digest.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "calculates digest from multiple writes" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    io = OpenSSL::DigestIO.new(base_io, base_digest, OpenSSL::DigestIO::DigestMode::Write)
    io.write("fo".to_slice)
    io.write("o".to_slice)
    base_io.to_slice[0, 3].should eq("foo".to_slice)

    io.digest.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae".hexbytes)
  end

  it "does not calculate digest on write" do
    base_io = IO::Memory.new
    base_digest = OpenSSL::Digest.new("SHA256")
    empty_digest = OpenSSL::Digest.new("SHA256").digest
    io = OpenSSL::DigestIO.new(base_io, base_digest, OpenSSL::DigestIO::DigestMode::Read)
    io.write("foo".to_slice)

    base_io.to_slice[0, 3].should eq("foo".to_slice)
    io.digest.should eq(empty_digest)
  end
end
