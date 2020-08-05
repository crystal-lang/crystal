require "../spec_helper"
require "socket"
require "../../support/fibers"
require "../../support/channel"
require "../../support/tempfile"

describe UNIXServer do
  describe ".new" do
    it "raises when path is too long" do
      with_tempfile("unix_server-too_long-#{("a" * 2048)}.sock") do |path|
        expect_raises(ArgumentError, "Path size exceeds the maximum size") do
          UNIXServer.new(path)
        end

        File.exists?(path).should be_false
      end
    end

    it "creates the socket file" do
      with_tempfile("unix_server.sock") do |path|
        UNIXServer.open(path) do
          File.exists?(path).should be_true
        end

        File.exists?(path).should be_false
      end
    end

    it "deletes socket file on close" do
      with_tempfile("unix_server-close.sock") do |path|
        server = UNIXServer.new(path)
        server.close

        File.exists?(path).should be_false
      end
    end

    it "raises when socket file already exists" do
      with_tempfile("unix_server-twice.sock") do |path|
        server = UNIXServer.new(path)

        begin
          expect_raises(Socket::BindError) do
            UNIXServer.new(path)
          end
        ensure
          server.close
        end
      end
    end

    it "won't delete existing file on bind failure" do
      with_tempfile("unix_server-exist.sock") do |path|
        File.write(path, "")
        File.exists?(path).should be_true

        expect_raises(Socket::BindError) do
          UNIXServer.new(path)
        end

        File.exists?(path).should be_true
      end
    end
  end

  describe "accept" do
    it "returns the client UNIXSocket" do
      with_tempfile("unix_server-accept.sock") do |path|
        UNIXServer.open(path) do |server|
          UNIXSocket.open(path) do |_|
            client = server.accept
            client.should be_a(UNIXSocket)
            client.close
          end
        end
      end
    end

    it "raises when server is closed" do
      with_tempfile("unix_server-closed.sock") do |path|
        server = UNIXServer.new(path)
        ch = Channel(Symbol).new(1)
        exception = nil

        schedule_timeout ch

        f = spawn do
          begin
            ch.send(:begin)
            server.accept
          rescue ex
            exception = ex
          end
          ch.send(:end)
        end

        ch.receive.should eq(:begin)

        # wait for the server to call accept
        wait_until_blocked f

        server.close
        ch.receive.should eq(:end)

        exception.should be_a(IO::Error)
        exception.try(&.message).should eq("Closed stream")
      end
    end
  end

  describe "accept?" do
    it "returns the client UNIXSocket" do
      with_tempfile("unix_server-accept_.sock") do |path|
        UNIXServer.open(path) do |server|
          UNIXSocket.open(path) do |_|
            client = server.accept?.not_nil!
            client.should be_a(UNIXSocket)
            client.close
          end
        end
      end
    end

    it "returns nil when server is closed" do
      with_tempfile("unix_server-accept2.sock") do |path|
        server = UNIXServer.new(path)
        ch = Channel(Symbol).new(1)
        ret = :initial

        schedule_timeout ch

        f = spawn do
          ch.send :begin
          ret = server.accept?
          ch.send :end
        end

        ch.receive.should eq(:begin)

        # wait for the server to call accept
        wait_until_blocked f

        server.close
        ch.receive.should eq(:end)

        ret.should be_nil
      end
    end
  end
end
