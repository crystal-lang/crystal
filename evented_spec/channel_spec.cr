require "./spec_helper"

describe Channel do
  it "creates unbuffered with no arguments" do
    Channel(Int32).new.should be_a(UnbufferedChannel(Int32))
  end

  it "creates buffered with capacity argument" do
    Channel(Int32).new(32).should be_a(BufferedChannel(Int32))
  end
end

describe UnbufferedChannel do
  it "pings" do
    ch = UnbufferedChannel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
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
    state.should eq(1)
    ch.receive.should eq(123)
    state.should eq(1)
    Scheduler.yield
    state.should eq(2)
  end

  it "deliver many senders" do
    ch = UnbufferedChannel(Int32).new
    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    (1..6).map { ch.receive }.sort.should eq([1, 2, 3, 4, 5, 6])
  end

  it "gets ready when there is a sender" do
    ch = UnbufferedChannel(Int32).new
    ch.ready?.should be_false
    spawn { ch.send 123 }
    Scheduler.yield
    ch.ready?.should be_true
    ch.receive.should eq(123)
  end

  it "works with select" do
    ch1 = UnbufferedChannel(Int32).new
    ch2 = UnbufferedChannel(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1, ch2).should eq(ch1)
  end
end

describe BufferedChannel do
  it "pings" do
    ch = BufferedChannel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks when full" do
    ch = BufferedChannel(Int32).new(2)
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
    ch = BufferedChannel(Int32).new
    done = false
    spawn { ch.send 123; done = true }
    done.should be_false
    Scheduler.yield
    done.should be_true
  end

  it "gets ready with data" do
    ch = BufferedChannel(Int32).new
    ch.ready?.should be_false
    ch.send 123
    ch.ready?.should be_true
  end

  it "works with select" do
    ch1 = BufferedChannel(Int32).new
    ch2 = BufferedChannel(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1, ch2).should eq(ch1)
  end
end
