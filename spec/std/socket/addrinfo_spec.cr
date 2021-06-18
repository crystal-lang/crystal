require "spec"
require "socket/addrinfo"

describe Socket::Addrinfo do
  describe ".resolve" do
    it "returns an array" do
      addrinfos = Socket::Addrinfo.resolve("localhost", 80, type: Socket::Type::STREAM)
      typeof(addrinfos).should eq(Array(Socket::Addrinfo))
      addrinfos.size.should_not eq(0)
    end

    it "yields each result" do
      Socket::Addrinfo.resolve("localhost", 80, type: Socket::Type::DGRAM) do |addrinfo|
        typeof(addrinfo).should eq(Socket::Addrinfo)
      end
    end

    it "eventually raises returned error" do
      expect_raises(Socket::Error) do
        Socket::Addrinfo.resolve("localhost", 80, type: Socket::Type::DGRAM) do |addrinfo|
          Socket::Error.new("please fail")
        end
      end
    end
  end

  describe ".tcp" do
    it "returns an array" do
      addrinfos = Socket::Addrinfo.tcp("localhost", 80)
      typeof(addrinfos).should eq(Array(Socket::Addrinfo))
      addrinfos.size.should_not eq(0)
    end

    it "yields each result" do
      Socket::Addrinfo.tcp("localhost", 80) do |addrinfo|
        typeof(addrinfo).should eq(Socket::Addrinfo)
      end
    end

    it "raises helpful message on getaddrinfo failure" do
      expect_raises(Socket::Addrinfo::Error, "Hostname lookup for badhostname failed: ") do
        Socket::Addrinfo.resolve("badhostname", 80, type: Socket::Type::DGRAM)
      end
    end
  end

  describe ".udp" do
    it "returns an array" do
      addrinfos = Socket::Addrinfo.udp("localhost", 80)
      typeof(addrinfos).should eq(Array(Socket::Addrinfo))
      addrinfos.size.should_not eq(0)
    end

    it "yields each result" do
      Socket::Addrinfo.udp("localhost", 80) do |addrinfo|
        typeof(addrinfo).should eq(Socket::Addrinfo)
      end
    end
  end

  describe "#ip_address" do
    it do
      addrinfos = Socket::Addrinfo.udp("localhost", 80)
      typeof(addrinfos.first.ip_address).should eq(Socket::IPAddress)
    end
  end

  it "#inspect" do
    addrinfos = Socket::Addrinfo.tcp("127.0.0.1", 12345)
    addrinfos.first.inspect.should eq "Socket::Addrinfo(127.0.0.1:12345, INET, STREAM, TCP)"

    addrinfos = Socket::Addrinfo.udp("127.0.0.1", 12345)
    addrinfos.first.inspect.should eq "Socket::Addrinfo(127.0.0.1:12345, INET, DGRAM, UDP)"
  end
end
