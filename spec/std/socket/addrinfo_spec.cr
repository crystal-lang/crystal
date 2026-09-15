require "spec"
require "socket"

describe Socket::Addrinfo, tags: "network" do
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

    it "resolves a service name" do
      addrinfos = Socket::Addrinfo.resolve("localhost", "http", type: Socket::Type::STREAM, protocol: Socket::Protocol::TCP)
      addrinfos.size.should_not eq(0)
      addrinfos.first.ip_address.port.should eq(80)
    end

    it "accepts the port number boundaries" do
      Socket::Addrinfo.resolve("127.0.0.1", 0, type: Socket::Type::STREAM).size.should_not eq(0)
      Socket::Addrinfo.resolve("127.0.0.1", 65535, type: Socket::Type::STREAM).size.should_not eq(0)
    end

    it "raises on out of range port number" do
      expect_raises(Socket::Error, "Invalid port number: 65536") do
        Socket::Addrinfo.resolve("127.0.0.1", 65536, type: Socket::Type::STREAM)
      end
    end

    it "raises on negative port number" do
      expect_raises(Socket::Error, "Invalid port number: -1") do
        Socket::Addrinfo.resolve("127.0.0.1", -1, type: Socket::Type::STREAM)
      end
    end

    it "raises helpful message on getaddrinfo failure" do
      expect_raises(Socket::Addrinfo::Error, "Hostname lookup for badhostname.unknown failed: ") do
        Socket::Addrinfo.resolve("badhostname.unknown", 80, type: Socket::Type::DGRAM)
      end
    end

    {% if flag?(:win32) %}
      it "raises timeout error" do
        expect_raises(IO::TimeoutError) do
          Socket::Addrinfo.resolve("badhostname", 80, type: Socket::Type::STREAM, timeout: 0.milliseconds)
        end
      end
    {% end %}
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

    it "raises on out of range port number" do
      expect_raises(Socket::Error, "Invalid port number: 70000") do
        Socket::Addrinfo.tcp("127.0.0.1", 70000)
      end
    end

    {% if flag?(:win32) %}
      it "raises timeout error" do
        expect_raises(IO::TimeoutError) do
          Socket::Addrinfo.tcp("badhostname", 80, timeout: 0.milliseconds)
        end
      end
    {% end %}
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

    it "raises on out of range port number" do
      expect_raises(Socket::Error, "Invalid port number: 70000") do
        Socket::Addrinfo.udp("127.0.0.1", 70000)
      end
    end

    {% if flag?(:win32) %}
      it "raises timeout error" do
        expect_raises(IO::TimeoutError) do
          Socket::Addrinfo.udp("badhostname", 80, timeout: 0.milliseconds)
        end
      end
    {% end %}
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

  describe "Error" do
    {% unless flag?(:win32) || flag?(:wasm32) %}
      # This method is not available on windows/wasm because windows/wasm support was introduced after deprecation.
      it ".new (deprecated)" do
        error = Socket::Addrinfo::Error.new(LibC::EAI_NONAME, "No address found", "foobar.com")
        error.os_error.should eq Errno.new(LibC::EAI_NONAME)
        error.message.should eq "Hostname lookup for foobar.com failed: No address found"
      end
    {% end %}
  end
end
