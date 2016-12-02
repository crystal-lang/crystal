require "spec"

describe Channel do
  it "creates unbuffered with no arguments" do
    Channel(Int32).new.should be_a(Channel::Unbuffered(Int32))
  end

  it "creates buffered with capacity argument" do
    Channel(Int32).new(32).should be_a(Channel::Buffered(Int32))
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

describe Channel::Unbuffered do
  it "pings" do
    ch = Channel::Unbuffered(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks if there is no receiver" do
    ch = Channel::Unbuffered(Int32).new
    state = 0
    spawn do
      state = 1
      ch.send 123
      state = 2
    end

    Fiber.yield
    state.should eq(1)
    ch.receive.should eq(123)
    state.should eq(1)
    Fiber.yield
    state.should eq(2)
  end

  it "deliver many senders" do
    ch = Channel::Unbuffered(Int32).new
    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    (1..6).map { ch.receive }.sort.should eq([1, 2, 3, 4, 5, 6])
  end

  it "gets not full when there is a sender" do
    ch = Channel::Unbuffered(Int32).new
    ch.full?.should be_true
    ch.empty?.should be_true
    spawn { ch.send 123 }
    Fiber.yield
    ch.empty?.should be_false
    ch.full?.should be_true
    ch.receive.should eq(123)
  end

  it "works with select" do
    ch1 = Channel::Unbuffered(Int32).new
    ch2 = Channel::Unbuffered(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "works with select else" do
    ch1 = Channel::Unbuffered(Int32).new
    Channel.select({ch1.receive_select_action}, true).should eq({1, nil})
  end

  it "can send and receive nil" do
    ch = Channel::Unbuffered(Nil).new
    spawn { ch.send nil }
    Fiber.yield
    ch.empty?.should be_false
    ch.receive.should be_nil
    ch.empty?.should be_true
  end

  it "can be closed" do
    ch = Channel::Unbuffered(Int32).new
    ch.closed?.should be_false
    ch.close.should be_nil
    ch.closed?.should be_true
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed after sending" do
    ch = Channel::Unbuffered(Int32).new
    spawn { ch.send 123; ch.close }
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel::Unbuffered(Int32).new
    received = false
    spawn { expect_raises(Channel::ClosedError) { ch.receive }; received = true }
    Fiber.yield
    ch.close
    Fiber.yield
    received.should be_true
  end

  it "cannot send if closed" do
    ch = Channel::Unbuffered(Int32).new
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end

  it "can receive? when closed" do
    ch = Channel::Unbuffered(Int32).new
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel::Unbuffered(Int32).new
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
  end
end

describe Channel::Buffered do
  it "pings" do
    ch = Channel::Buffered(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks when full" do
    ch = Channel::Buffered(Int32).new(2)
    freed = false
    spawn { 2.times { ch.receive }; freed = true }

    ch.send 1
    ch.full?.should be_false
    freed.should be_false

    ch.send 2
    ch.full?.should be_true
    freed.should be_false

    ch.send 3
    ch.full?.should be_false
    freed.should be_true
  end

  it "doesn't block when not full" do
    ch = Channel::Buffered(Int32).new
    done = false
    spawn { ch.send 123; done = true }
    done.should be_false
    Fiber.yield
    done.should be_true
  end

  it "gets ready with data" do
    ch = Channel::Buffered(Int32).new
    ch.empty?.should be_true
    ch.send 123
    ch.empty?.should be_false
  end

  it "works with select" do
    ch1 = Channel::Buffered(Int32).new
    ch2 = Channel::Buffered(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "can send and receive nil" do
    ch = Channel::Buffered(Nil).new
    spawn { ch.send nil }
    Fiber.yield
    ch.empty?.should be_false
    ch.receive.should be_nil
    ch.empty?.should be_true
  end

  it "can be closed" do
    ch = Channel::Buffered(Int32).new
    ch.closed?.should be_false
    ch.close
    ch.closed?.should be_true
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed after sending" do
    ch = Channel::Buffered(Int32).new
    spawn { ch.send 123; ch.close }
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel::Buffered(Int32).new
    received = false
    spawn { expect_raises(Channel::ClosedError) { ch.receive }; received = true }
    Fiber.yield
    ch.close
    Fiber.yield
    received.should be_true
  end

  it "cannot send if closed" do
    ch = Channel::Buffered(Int32).new
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end

  it "can receive? when closed" do
    ch = Channel::Buffered(Int32).new
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel::Buffered(Int32).new
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
  end

  it "does inspect on unbuffered channel" do
    ch = Channel::Unbuffered(Int32).new
    ch.inspect.should eq("#<Channel::Unbuffered(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does inspect on buffered channel" do
    ch = Channel::Buffered(Int32).new(10)
    ch.inspect.should eq("#<Channel::Buffered(Int32):0x#{ch.object_id.to_s(16)}>")
  end
end
