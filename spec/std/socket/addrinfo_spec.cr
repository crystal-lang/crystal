require "spec"
require "socket"
require "socket/addrinfo/threaded"
require "socket/addrinfo/evented"

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
      expect_raises(Socket::Error) do |addrinfo|
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

  describe "Blocking resolver" do
    resolver = Socket::Addrinfo::Blocking.new

    it "resolves domain" do
      resolver.getaddrinfo("localhost", 80, Socket::Family::UNSPEC, Socket::Type::STREAM) do |addrinfo|
        addrinfo.ip_address.to_s.should eq("127.0.0.1:80")
      end
    end

    it "fails to resolve unknown domain" do
      expect_raises(Socket::Error) do
        resolver.getaddrinfo("unknown.example.org", 21, Socket::Family::UNSPEC, Socket::Type::STREAM) { }
      end
    end
  end

  describe "Threaded resolver" do
    resolver = Socket::Addrinfo::Threaded.new(size: 2)

    it "resolves domain" do
      resolver.getaddrinfo("localhost", 80, Socket::Family::UNSPEC, Socket::Type::STREAM) do |addrinfo|
        addrinfo.ip_address.to_s.should eq("127.0.0.1:80")
      end
    end

    it "fails to resolve unknown domain" do
      expect_raises(Socket::Error) do
        resolver.getaddrinfo("unknown.example.org", 21, Socket::Family::UNSPEC, Socket::Type::STREAM) { }
      end
    end
  end

  describe "Evented resolver" do
    resolver = Socket::Addrinfo::Evented.new

    it "resolves domain" do
      resolver.getaddrinfo("localhost", 80, Socket::Family::UNSPEC, Socket::Type::STREAM) do |addrinfo|
        addrinfo.ip_address.to_s.should eq("127.0.0.1:80")
      end
    end

    it "fails to resolve unknown domain" do
      expect_raises(Socket::Error) do
        resolver.getaddrinfo("unknown.example.org", 21, Socket::Family::UNSPEC, Socket::Type::STREAM) { }
      end
    end
  end
end
