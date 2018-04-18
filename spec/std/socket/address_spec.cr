require "spec"
require "socket/address"

describe Socket::IPAddress do
  it "transforms an IPv4 address into a C struct and back" do
    addr1 = Socket::IPAddress.new("127.0.0.1", 8080)
    addr2 = Socket::IPAddress.from(addr1.to_unsafe, addr1.size)

    addr2.family.should eq(addr1.family)
    addr2.port.should eq(addr1.port)
    typeof(addr2.address).should eq(String)
    addr2.address.should eq(addr1.address)
  end

  it "transforms an IPv6 address into a C struct and back" do
    addr1 = Socket::IPAddress.new("2001:db8:8714:3a90::12", 8080)
    addr2 = Socket::IPAddress.from(addr1.to_unsafe, addr1.size)

    addr2.family.should eq(addr1.family)
    addr2.port.should eq(addr1.port)
    typeof(addr2.address).should eq(String)
    addr2.address.should eq(addr1.address)
  end

  it "won't resolve domains" do
    expect_raises(Socket::Error, /Invalid IP address/) do
      Socket::IPAddress.new("localhost", 1234)
    end
  end

  it "to_s" do
    Socket::IPAddress.new("127.0.0.1", 80).to_s.should eq("127.0.0.1:80")
    Socket::IPAddress.new("2001:db8:8714:3a90::12", 443).to_s.should eq("[2001:db8:8714:3a90::12]:443")
  end
end

describe Socket::UNIXAddress do
  it "transforms into a C struct and back" do
    path = "unix_address.sock"

    addr1 = Socket::UNIXAddress.new(path)
    addr2 = Socket::UNIXAddress.from(addr1.to_unsafe, addr1.size)

    addr2.family.should eq(addr1.family)
    addr2.path.should eq(addr1.path)
    addr2.to_s.should eq(path)
  end

  it "raises when path is too long" do
    path = "unix_address-too-long-#{("a" * 2048)}.sock"

    expect_raises(ArgumentError, "Path size exceeds the maximum size") do
      Socket::UNIXAddress.new(path)
    end
  end

  it "to_s" do
    Socket::UNIXAddress.new("some_path").to_s.should eq("some_path")
  end
end
