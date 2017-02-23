require "../spec_helper"

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
    switch = FiberSwitch.new
    ch = Channel::Unbuffered(Int32).new
    state = 0

    spawn do
      switch.wait_and_defer_yield 1, 0

      ch.send 123
      state = 1

      switch.wait_and_yield 1, 0
    end

    switch.yield_and_wait 1, 0

    state.should eq(0)
    ch.receive.should eq(123)

    switch.yield_and_wait 1, 0

    state.should eq(1)
  end

  it "deliver many senders" do
    ch = Channel::Unbuffered(Int32).new
    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    (1..6).map { ch.receive }.sort.should eq([1, 2, 3, 4, 5, 6])
  end

  it "gets not empty when there is a sender" do
    switch = FiberSwitch.new
    ch = Channel::Unbuffered(Int32).new
    ch.full?.should be_true
    ch.empty?.should be_true
    spawn do
      switch.wait_and_defer_yield 1, 0
      ch.send 123
    end
    switch.yield_and_wait 1, 0
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
    switch = FiberSwitch.new
    ch = Channel::Unbuffered(Nil).new
    spawn do
      switch.wait_and_defer_yield 1, 0
      ch.send nil
    end
    switch.yield_and_wait 1, 0
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
    switch = FiberSwitch.new
    ch = Channel::Unbuffered(Int32).new
    received = false
    spawn do
      switch.wait_and_defer_yield 1, 0
      expect_raises(Channel::ClosedError) { ch.receive }
      received = true
      switch.wait_and_yield 1, 0
    end
    switch.yield_and_wait 1, 0
    ch.close
    switch.yield_and_wait 1, 0
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
    switch = FiberSwitch.new
    ch = Channel::Buffered(Int32).new(2)
    freed = false
    spawn do
      switch.wait 1
      2.times { ch.receive }
      freed = true
      switch.yield 0
    end

    ch.send 1
    ch.full?.should be_false
    freed.should be_false

    ch.send 2
    ch.full?.should be_true
    freed.should be_false

    switch.defer_yield 1
    ch.send 3
    switch.wait 0
    ch.full?.should be_false
    freed.should be_true
  end

  it "doesn't block when not full" do
    switch = FiberSwitch.new
    ch = Channel::Buffered(Int32).new
    done = false
    spawn do
      switch.wait 1
      ch.send 123
      done = true
      switch.yield 0
    end
    done.should be_false
    switch.yield_and_wait 1, 0
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
    switch = FiberSwitch.new
    ch = Channel::Buffered(Nil).new
    spawn do
      switch.wait 1
      ch.send nil
      switch.yield 0
    end
    switch.yield_and_wait 1, 0
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
    switch = FiberSwitch.new
    ch = Channel::Buffered(Int32).new
    received = false
    spawn do
      switch.wait_and_defer_yield 1, 0
      expect_raises(Channel::ClosedError) { ch.receive }
      received = true
      switch.wait_and_yield 1, 0
    end
    switch.yield_and_wait 1, 0
    ch.close
    switch.yield_and_wait 1, 0
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

  it "does pretty_inspect on unbuffered channel" do
    ch = Channel::Unbuffered(Int32).new
    ch.pretty_inspect.should eq("#<Channel::Unbuffered(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does pretty_inspect on buffered channel" do
    ch = Channel::Buffered(Int32).new(10)
    ch.pretty_inspect.should eq("#<Channel::Buffered(Int32):0x#{ch.object_id.to_s(16)}>")
  end
end
