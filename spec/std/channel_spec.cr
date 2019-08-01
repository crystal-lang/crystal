require "spec"

private def yield_to(fiber)
  Crystal::Scheduler.enqueue(Fiber.current)
  Crystal::Scheduler.resume(fiber)
end

describe Channel do
  it "creates unbuffered with no arguments" do
    Channel(Int32).new
  end

  it "creates buffered with capacity argument" do
    Channel(Int32).new(32)
  end

  it "send returns channel" do
    channel = Channel(Int32).new(1)
    channel.send(1).should be(channel)
  end

  it "does receive_first" do
    channel = Channel(Int32).new(1)
    channel.send(1)
    Channel.receive_first(Channel(Int32).new, channel).should eq 1
  end

  it "does send_first" do
    ch1 = Channel(Int32).new(1)
    ch2 = Channel(Int32).new(1)
    ch1.send(1)
    Channel.send_first(2, ch1, ch2)
    ch2.receive.should eq 2
  end
end

describe "unbuffered" do
  it "pings" do
    ch = Channel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks if there is no receiver" do
    ch = Channel(Int32).new
    state = 0
    main = Fiber.current

    sender = Fiber.new do
      state = 1
      ch.send 123
      state = 2
    ensure
      yield_to(main)
    end

    yield_to(sender)
    state.should eq(1)
    ch.receive.should eq(123)
    state.should eq(1)

    sleep
    state.should eq(2)
  end

  it "deliver many senders" do
    ch = Channel(Int32).new
    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    (1..6).map { ch.receive }.sort.should eq([1, 2, 3, 4, 5, 6])
  end

  it "works with select" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "works with select else" do
    ch1 = Channel(Int32).new
    Channel.select({ch1.receive_select_action}, true).should eq({1, Channel::NotReady})
  end

  it "can send and receive nil" do
    ch = Channel(Nil).new
    sender = Fiber.new { ch.send nil }
    yield_to(sender)
    ch.receive.should be_nil
  end

  it "can be closed" do
    ch = Channel(Int32).new
    ch.closed?.should be_false
    ch.close.should be_nil
    ch.closed?.should be_true
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed after sending" do
    ch = Channel(Int32).new
    spawn { ch.send 123; ch.close }
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel(Int32).new
    closed = false
    main = Fiber.current

    receiver = Fiber.new do
      expect_raises(Channel::ClosedError) { ch.receive }
      closed = true
    ensure
      yield_to(main)
    end

    yield_to(receiver)
    ch.close

    sleep
    closed.should be_true
  end

  it "cannot send if closed" do
    ch = Channel(Int32).new
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end

  it "can receive? when closed" do
    ch = Channel(Int32).new
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel(Int32).new
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
  end

  it "wakes up sender fiber when channel is closed" do
    ch = Channel(Nil).new
    closed = false
    main = Fiber.current

    sender = Fiber.new do
      begin
        ch.send(nil)
      rescue Channel::ClosedError
        closed = true
      end
      yield_to(main)
    end

    yield_to(sender)

    ch.close
    sleep

    closed.should be_true
  end

  it "wakes up receiver fibers when channel is closed" do
    ch = Channel(Nil).new
    closed = false
    main = Fiber.current

    receiver = Fiber.new do
      ch.receive
    rescue Channel::ClosedError
      closed = ch.closed?
    ensure
      yield_to(main)
    end

    yield_to(receiver)

    ch.close
    sleep

    closed.should be_true
  end
end

describe "buffered" do
  it "pings" do
    ch = Channel(Int32).new(10)
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks when full" do
    ch = Channel(Int32).new(2)
    freed = false
    spawn { 2.times { ch.receive }; freed = true }

    ch.send 1
    freed.should be_false

    ch.send 2
    freed.should be_false

    ch.send 3
    freed.should be_true
  end

  it "doesn't block when not full" do
    ch = Channel(Int32).new(10)
    done = false
    sender = Fiber.new { ch.send 123; done = true }
    yield_to(sender)
    done.should be_true
  end

  it "gets ready with data" do
    ch = Channel(Int32).new(10)
    ch.send 123
    ch.receive.should eq(123)
  end

  it "works with select" do
    ch1 = Channel(Int32).new(10)
    ch2 = Channel(Int32).new(10)
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "can send and receive nil" do
    ch = Channel(Nil).new(10)
    sender = Fiber.new { ch.send nil }
    yield_to(sender)
    ch.receive.should be_nil
  end

  it "can be closed" do
    ch = Channel(Int32).new(10)
    ch.closed?.should be_false
    ch.close
    ch.closed?.should be_true
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed after sending" do
    ch = Channel(Int32).new(10)
    ch.send 123
    ch.close
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel(Int32).new(10)
    received = false
    main = Fiber.current

    receiver = Fiber.new do
      expect_raises(Channel::ClosedError) { ch.receive }
      received = true
    ensure
      yield_to(main)
    end

    yield_to(receiver)
    ch.close
    sleep
    received.should be_true
  end

  it "cannot send if closed" do
    ch = Channel(Int32).new(10)
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end

  it "can receive? when closed" do
    ch = Channel(Int32).new(10)
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel(Int32).new(10)
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
  end

  it "does inspect on unbuffered channel" do
    ch = Channel(Int32).new
    ch.inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does inspect on buffered channel" do
    ch = Channel(Int32).new(10)
    ch.inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does pretty_inspect on unbuffered channel" do
    ch = Channel(Int32).new
    ch.pretty_inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does pretty_inspect on buffered channel" do
    ch = Channel(Int32).new(10)
    ch.pretty_inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end
end
