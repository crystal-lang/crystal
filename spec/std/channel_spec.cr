require "spec"

describe Channel do
  it "creates unbuffered with no arguments" do
    expect(Channel(Int32).new).to be_a(UnbufferedChannel(Int32))
  end

  it "creates buffered with capacity argument" do
    expect(Channel(Int32).new(32)).to be_a(BufferedChannel(Int32))
  end
end

describe UnbufferedChannel do
  it "pings" do
    ch = UnbufferedChannel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    expect(ch.receive).to eq(123)
  end

  it "blocks if there is no receiver" do
    ch = UnbufferedChannel(Int32).new
    state = 0
    spawn do
      state = 1
      ch.send 123
      state = 2
    end

    Scheduler.yield
    expect(state).to eq(1)
    expect(ch.receive).to eq(123)
    expect(state).to eq(1)
    Scheduler.yield
    expect(state).to eq(2)
  end

  it "deliver many senders" do
    ch = UnbufferedChannel(Int32).new
    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    expect((1..6).map { ch.receive }.sort).to eq([1, 2, 3, 4, 5, 6])
  end

  it "gets ready when there is a sender" do
    ch = UnbufferedChannel(Int32).new
    expect(ch.ready?).to be_false
    spawn { ch.send 123 }
    Scheduler.yield
    expect(ch.ready?).to be_true
    expect(ch.receive).to eq(123)
  end

  it "works with select" do
    ch1 = UnbufferedChannel(Int32).new
    ch2 = UnbufferedChannel(Int32).new
    spawn { ch1.send 123 }
    expect(Channel.select(ch1, ch2)).to eq(ch1)
  end
end

describe BufferedChannel do
  it "pings" do
    ch = BufferedChannel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    expect(ch.receive).to eq(123)
  end

  it "blocks when full" do
    ch = BufferedChannel(Int32).new(2)
    freed = false
    spawn { 2.times { ch.receive }; freed = true }

    ch.send 1
    expect(ch.full?).to be_false
    expect(freed).to be_false

    ch.send 2
    expect(ch.full?).to be_true
    expect(freed).to be_false

    ch.send 3
    expect(ch.full?).to be_false
    expect(freed).to be_true
  end

  it "doesn't block when not full" do
    ch = BufferedChannel(Int32).new
    done = false
    spawn { ch.send 123; done = true }
    expect(done).to be_false
    Scheduler.yield
    expect(done).to be_true
  end

  it "gets ready with data" do
    ch = BufferedChannel(Int32).new
    expect(ch.ready?).to be_false
    ch.send 123
    expect(ch.ready?).to be_true
  end

  it "works with select" do
    ch1 = BufferedChannel(Int32).new
    ch2 = BufferedChannel(Int32).new
    spawn { ch1.send 123 }
    expect(Channel.select(ch1, ch2)).to eq(ch1)
  end
end
