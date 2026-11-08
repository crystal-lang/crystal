{% skip_file if flag?(:wasm32) %}

require "./spec_helper"

# Fake socket to drive `Socket::HappyEyeballs.connect` deterministically.
private class FakeSocket
  getter address : String
  getter? closed = false
  getter? finished = false
  getter timeout : Time::Span?

  @cancel = Channel(Nil).new(1)
  @release = Channel(Nil).new(1)
  @released = false

  def initialize(@address, @behavior : Symbol)
  end

  def connect(addrinfo, timeout, &)
    @timeout = timeout
    case @behavior
    when :success
      # connected
    when :wait
      # succeed once released (see #release), unless closed before
      select
      when @release.receive
      when @cancel.receive
        yield IO::Error.new("Closed stream")
      end
    when :fail
      yield Socket::ConnectError.new("Connection refused")
    when :stall
      # wait for #close to cancel the attempt, or the timeout
      if timeout
        select
        when @cancel.receive
          yield IO::Error.new("Closed stream")
        when timeout(timeout)
          yield IO::TimeoutError.new("Connect timed out")
        end
      else
        @cancel.receive
        yield IO::Error.new("Closed stream")
      end
    end
  ensure
    @finished = true
  end

  # Lets a `:wait` attempt succeed.
  def release : Nil
    return if @released
    @released = true
    @release.send(nil)
  end

  def close : Nil
    return if @closed
    @closed = true
    @cancel.send(nil)
  end
end

private def addrinfos(*addresses)
  addresses.map { |address| Socket::Addrinfo.tcp(address, 80).first }.to_a
end

# Runs `HappyEyeballs.connect` with a fake socket per address, whose behavior
# is given by *behaviors* (indexed by address). Creating the attempt for the
# *release_on* address lets the previous `:wait` attempts succeed, which orders
# events deterministically without relying on timers.
#
# The default *delay* is long so that the next attempt only starts on failure,
# even when the event loop wakes up late (e.g. on CI).
private def happy_eyeballs(addrinfos, behaviors : Hash(String, Symbol), delay = 10.seconds, connect_timeout = nil, release_on = nil)
  sockets = [] of FakeSocket
  result = Socket::HappyEyeballs.connect(addrinfos, connect_timeout, delay) do |addrinfo|
    address = addrinfo.ip_address.address
    sockets.each(&.release) if address == release_on
    socket = FakeSocket.new(address, behaviors[address])
    sockets << socket
    socket
  end
  {result, sockets}
end

describe Socket::HappyEyeballs do
  describe ".interleave" do
    it "alternates families, starting with the first family and keeping the order within families" do
      v6 = addrinfos("::1", "::2", "::3")
      v4 = addrinfos("127.0.0.1", "127.0.0.2")

      Socket::HappyEyeballs.interleave(v6 + v4).map(&.ip_address.address)
        .should eq(["::1", "127.0.0.1", "::2", "127.0.0.2", "::3"])

      Socket::HappyEyeballs.interleave(v4 + v6).map(&.ip_address.address)
        .should eq(["127.0.0.1", "::1", "127.0.0.2", "::2", "::3"])

      Socket::HappyEyeballs.interleave(addrinfos("::2", "127.0.0.1", "::1")).map(&.ip_address.address)
        .should eq(["::2", "127.0.0.1", "::1"])
    end

    it "keeps a single family as is" do
      Socket::HappyEyeballs.interleave(addrinfos("127.0.0.2", "127.0.0.1")).map(&.ip_address.address)
        .should eq(["127.0.0.2", "127.0.0.1"])
      Socket::HappyEyeballs.interleave(addrinfos("::1")).map(&.ip_address.address).should eq(["::1"])
      Socket::HappyEyeballs.interleave([] of Socket::Addrinfo).should be_empty
    end
  end

  describe ".connect" do
    it "returns the first success without starting unnecessary attempts" do
      result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1"), {"::1" => :success, "127.0.0.1" => :success})

      sockets.map(&.address).should eq(["::1"])
      result.should be(sockets[0])
      sockets[0].closed?.should be_false
    end

    it "starts the next attempt immediately after a failure" do
      result, sockets = nil, nil
      elapsed = Time.measure do
        result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1"), {"::1" => :fail, "127.0.0.1" => :success}, delay: 10.seconds)
      end
      elapsed.should be < 5.seconds

      sockets = sockets.should_not be_nil
      result.should be(sockets[1])
      sockets[0].closed?.should be_true
      sockets[1].closed?.should be_false
    end

    it "starts the next attempt in parallel after the delay and cancels the loser" do
      result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1"), {"::1" => :stall, "127.0.0.1" => :success},
        delay: 1.millisecond, connect_timeout: 10.seconds)

      result.should be(sockets[1])
      sockets[0].closed?.should be_true
      sockets[0].finished?.should be_true
      sockets[1].closed?.should be_false

      # the timeout applies to the whole race
      timeouts = sockets.map(&.timeout.should_not(be_nil))
      timeouts[0].should be <= 10.seconds
      timeouts[1].should be < timeouts[0]
    end

    it "lets an earlier attempt win after a later attempt started" do
      result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1"), {"::1" => :wait, "127.0.0.1" => :stall},
        delay: 1.millisecond, release_on: "127.0.0.1")

      sockets.size.should eq(2)
      result.should be(sockets[0])
      sockets[0].closed?.should be_false
      sockets[1].closed?.should be_true
      sockets[1].finished?.should be_true
    end

    it "keeps an earlier attempt pending when a later attempt fails" do
      result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1", "::2"),
        {"::1" => :wait, "127.0.0.1" => :fail, "::2" => :stall}, delay: 1.millisecond, release_on: "::2")

      result.should be(sockets[0])
      sockets[0].closed?.should be_false
      sockets[1].closed?.should be_true
      sockets[2].closed?.should be_true
      sockets[2].finished?.should be_true
    end

    it "times out the whole race at once" do
      behaviors = {"::1" => :stall, "127.0.0.1" => :stall}
      result, sockets = nil, nil
      elapsed = Time.measure do
        result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1"), behaviors, delay: 1.millisecond, connect_timeout: 1.second)
      end
      elapsed.should be >= 1.second

      result.should be_a(IO::TimeoutError)
      sockets = sockets.should_not be_nil
      sockets.size.should eq(2)
      sockets.all?(&.finished?).should be_true

      # the later attempt only got the time remaining until the deadline (an
      # individual timeout per attempt would give each attempt 1 second)
      timeouts = sockets.map(&.timeout.should_not(be_nil))
      timeouts[0].should be <= 1.second
      timeouts[1].should be < timeouts[0]
    end

    it "doesn't start attempts after the timeout" do
      addresses = (1..20).map { |i| "127.0.0.#{i}" }
      behaviors = addresses.to_h { |address| {address, :stall} }
      list = addresses.map { |address| Socket::Addrinfo.tcp(address, 80).first }
      result, sockets = happy_eyeballs(list, behaviors, delay: 10.milliseconds, connect_timeout: 50.milliseconds)

      result.should be_a(IO::TimeoutError)
      sockets.size.should be < 20
      sockets.all?(&.finished?).should be_true
    end

    it "returns the last error and closes every socket when all attempts fail" do
      result, sockets = happy_eyeballs(addrinfos("::1", "127.0.0.1"), {"::1" => :fail, "127.0.0.1" => :fail})

      result.should be_a(Socket::ConnectError)
      sockets.size.should eq(2)
      sockets.all?(&.closed?).should be_true
      sockets.all?(&.finished?).should be_true
    end

    it "returns nil without addresses" do
      result, sockets = happy_eyeballs([] of Socket::Addrinfo, {} of String => Symbol)
      result.should be_nil
      sockets.should be_empty
    end

    it "skips an address when creating its socket fails" do
      sockets = [] of FakeSocket
      result = Socket::HappyEyeballs.connect(addrinfos("::1", "127.0.0.1"), delay: 10.seconds) do |addrinfo|
        raise Socket::Error.new("Address family not supported") if addrinfo.family.inet6?
        socket = FakeSocket.new(addrinfo.ip_address.address, :success)
        sockets << socket
        socket
      end

      sockets.map(&.address).should eq(["127.0.0.1"])
      result.should be(sockets[0])
    end

    it "returns the socket creation error when no socket could be created" do
      result = Socket::HappyEyeballs.connect(addrinfos("::1", "127.0.0.1")) do |addrinfo|
        raise Socket::Error.new("Failed #{addrinfo.ip_address.address}")
        FakeSocket.new("", :success)
      end

      result.should be_a(Socket::Error)
      result.as(Exception).message.should eq("Failed 127.0.0.1")
    end
  end
end
