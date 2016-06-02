require "spec"
require "socket"
require "openssl"

private def connect_to(host, context = OpenSSL::SSL::Context::Client.new)
  io = TCPSocket.new(host, 443)
  socket = OpenSSL::SSL::Socket::Client.new(io, context: context, hostname: host)
  socket << "GET / HTTP/1.1\r\nHost: #{host}\r\n\r\n"
  socket.gets
  true
ensure
  io.close if io
  socket.close if socket
end

describe "OpenSSL::SSL::Context has sane client defaults" do
  {
    "expired.badssl.com",
    "wrong.host.badssl.com",
    "self-signed.badssl.com",
    "incomplete-chain.badssl.com",
    "superfish.badssl.com",
    "edellroot.badssl.com",
    "dsdtestprovider.badssl.com",
    "subdomain.preloaded-hsts.badssl.com",
  }.each do |host|
    it "shouldn't connect to #{host}" do
      expect_raises(OpenSSL::SSL::Error) do
        connect_to(host)
      end
    end

    it "should connect to #{host} with verification disabled" do
      context = OpenSSL::SSL::Context::Client.new
      context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
      connect_to(host, context).should be_true
    end
  end

  {
    "rc4.badssl.com",
    "10000-sans.badssl.com",
    "dh480.badssl.com",
  }.each do |host|
    it "shouldn't connect to #{host}" do
      expect_raises(OpenSSL::SSL::Error) do
        connect_to(host)
      end
    end

    it "shouldn't connect to #{host} with verification disabled" do
      context = OpenSSL::SSL::Context::Client.new
      context.verify_mode = OpenSSL::SSL::VerifyMode::NONE

      expect_raises(OpenSSL::SSL::Error) do
        connect_to(host, context).should be_true
      end
    end
  end

  {
    "google.com",
    "sha1-2016.badssl.com",
    "sha1-2017.badssl.com",
    "sha256.badssl.com",
    "1000-sans.badssl.com",
    "rsa8192.badssl.com",
    "mixed-script.badssl.com",
    "very.badssl.com",
    "mixed.badssl.com",
    "mixed-favicon.badssl.com",
    "cbc.badssl.com",
    "mozilla-old.badssl.com",
    "mozilla-intermediate.badssl.com",
    "mozilla-modern.badssl.com",
    "dh1024.badssl.com",
    "dh2048.badssl.com",
    "dh-small-subgroup.badssl.com",
    "dh-composite.badssl.com",
    "hsts.badssl.com",
    "upgrade.badssl.com",
    "preloaded-hsts.badssl.com",
  }.each do |host|
    it "should connect to #{host} successfully" do
      connect_to(host).should be_true
    end
  end
end
