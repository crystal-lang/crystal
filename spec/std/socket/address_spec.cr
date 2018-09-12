require "spec"
require "socket"

describe Socket::Address do
  describe ".parse" do
    it "accepts URI" do
      address = Socket::Address.parse URI.parse("tcp://192.168.0.1:8081")
      address.should eq Socket::IPAddress.new("192.168.0.1", 8081)
    end

    it "parses TCP" do
      address = Socket::Address.parse "tcp://192.168.0.1:8081"
      address.should eq Socket::IPAddress.new("192.168.0.1", 8081)
    end

    it "parses UDP" do
      address = Socket::Address.parse "udp://192.168.0.1:8081"
      address.should eq Socket::IPAddress.new("192.168.0.1", 8081)
    end

    it "parses UNIX" do
      address = Socket::Address.parse "unix://socket.sock"
      address.should eq Socket::UNIXAddress.new("socket.sock")
    end

    it "fails with unknown scheme" do
      expect_raises(Socket::Error, "Unsupported address type: ssl") do
        Socket::Address.parse "ssl://192.168.0.1:8081"
      end
    end
  end
end

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

  describe ".parse" do
    it "parses IPv4" do
      address = Socket::IPAddress.parse "ip://192.168.0.1:8081"
      address.should eq Socket::IPAddress.new("192.168.0.1", 8081)
    end

    it "parses IPv6" do
      address = Socket::IPAddress.parse "ip://[::1]:8081"
      address.should eq Socket::IPAddress.new("::1", 8081)
    end

    it "fails host name" do
      expect_raises(Socket::Error, "Invalid IP address: example.com") do
        Socket::IPAddress.parse "ip://example.com:8081"
      end
    end

    it "ignores path and params" do
      address = Socket::IPAddress.parse "ip://192.168.0.1:8081/foo?bar=baz"
      address.should eq Socket::IPAddress.new("192.168.0.1", 8081)
    end

    it "fails with missing host" do
      expect_raises(Socket::Error, "Invalid IP address: missing host") do
        Socket::IPAddress.parse "ip:///path"
      end
    end

    it "fails with missing port" do
      expect_raises(Socket::Error, "Invalid IP address: missing port") do
        Socket::IPAddress.parse "ip://127.0.0.1"
      end
    end
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

  describe ".parse" do
    it "parses relative" do
      address = Socket::UNIXAddress.parse "unix://foo.sock"
      address.should eq Socket::UNIXAddress.new("foo.sock")
    end

    it "parses relative subpath" do
      address = Socket::UNIXAddress.parse "unix://foo/bar.sock"
      address.should eq Socket::UNIXAddress.new("foo/bar.sock")
    end

    it "parses relative dot" do
      address = Socket::UNIXAddress.parse "unix://./bar.sock"
      address.should eq Socket::UNIXAddress.new("./bar.sock")
    end

    it "relative with" do
      address = Socket::UNIXAddress.parse "unix://foo:21/bar.sock"
      address.should eq Socket::UNIXAddress.new("foo:21/bar.sock")
    end

    it "parses absolute" do
      address = Socket::UNIXAddress.parse "unix:///foo.sock"
      address.should eq Socket::UNIXAddress.new("/foo.sock")
    end

    it "ignores params" do
      address = Socket::UNIXAddress.parse "unix:///foo.sock?bar=baz"
      address.should eq Socket::UNIXAddress.new("/foo.sock")
    end

    it "fails with missing path" do
      expect_raises(Socket::Error, "Invalid UNIX address: missing path") do
        Socket::UNIXAddress.parse "unix://?foo=bar"
      end
    end
  end
end

describe Socket do
  # Tests from libc-test:
  # http://repo.or.cz/libc-test.git/blob/master:/src/functional/inet_pton.c
  it ".ip?" do
    # dotted-decimal notation
    Socket.ip?("0.0.0.0").should be_true
    Socket.ip?("127.0.0.1").should be_true
    Socket.ip?("10.0.128.31").should be_true
    Socket.ip?("255.255.255.255").should be_true

    # numbers-and-dots notation, but not dotted-decimal
    # Socket.ip?("1.2.03.4").should be_false # fails on darwin
    Socket.ip?("1.2.0x33.4").should be_false
    Socket.ip?("1.2.0XAB.4").should be_false
    Socket.ip?("1.2.0xabcd").should be_false
    Socket.ip?("1.0xabcdef").should be_false
    Socket.ip?("00377.0x0ff.65534").should be_false

    # invalid
    Socket.ip?(".1.2.3").should be_false
    Socket.ip?("1..2.3").should be_false
    Socket.ip?("1.2.3.").should be_false
    Socket.ip?("1.2.3.4.5").should be_false
    Socket.ip?("1.2.3.a").should be_false
    Socket.ip?("1.256.2.3").should be_false
    Socket.ip?("1.2.4294967296.3").should be_false
    Socket.ip?("1.2.-4294967295.3").should be_false
    Socket.ip?("1.2. 3.4").should be_false

    # ipv6
    Socket.ip?(":").should be_false
    Socket.ip?("::").should be_true
    Socket.ip?("::1").should be_true
    Socket.ip?(":::").should be_false
    Socket.ip?(":192.168.1.1").should be_false
    Socket.ip?("::192.168.1.1").should be_true
    Socket.ip?("0:0:0:0:0:0:192.168.1.1").should be_true
    Socket.ip?("0:0::0:0:0:192.168.1.1").should be_true
    # Socket.ip?("::012.34.56.78").should be_false # fails on darwin
    Socket.ip?(":ffff:192.168.1.1").should be_false
    Socket.ip?("::ffff:192.168.1.1").should be_true
    Socket.ip?(".192.168.1.1").should be_false
    Socket.ip?(":.192.168.1.1").should be_false
    Socket.ip?("a:0b:00c:000d:E:F::").should be_true
    # Socket.ip?("a:0b:00c:000d:0000e:f::").should be_false # fails on GNU libc
    Socket.ip?("1:2:3:4:5:6::").should be_true
    Socket.ip?("1:2:3:4:5:6:7::").should be_true
    Socket.ip?("1:2:3:4:5:6:7:8::").should be_false
    Socket.ip?("1:2:3:4:5:6:7::9").should be_false
    Socket.ip?("::1:2:3:4:5:6").should be_true
    Socket.ip?("::1:2:3:4:5:6:7").should be_true
    Socket.ip?("::1:2:3:4:5:6:7:8").should be_false
    Socket.ip?("a:b::c:d:e:f").should be_true
    Socket.ip?("ffff:c0a8:5e4").should be_false
    Socket.ip?(":ffff:c0a8:5e4").should be_false
    Socket.ip?("0:0:0:0:0:ffff:c0a8:5e4").should be_true
    Socket.ip?("0:0:0:0:ffff:c0a8:5e4").should be_false
    Socket.ip?("0::ffff:c0a8:5e4").should be_true
    Socket.ip?("::0::ffff:c0a8:5e4").should be_false
    Socket.ip?("c0a8").should be_false
  end
end
