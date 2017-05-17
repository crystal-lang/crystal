require "spec"

describe Channel do
  it "pings" do
    ch = Channel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "send returns value of which send" do
    channel = Channel(Int32).new(1)
    channel.send(1).should eq(1)
  end

  it "blocks in sending when buffer is full" do
    ch = Channel(Int32).new

    state = 0
    spawn do
      state = 1
      ch.send 123
      state = 2
    end

    ch.full?.should be_true
    Fiber.yield
    state.should eq(1)
    ch.full?.should be_true
    ch.receive.should eq(123)
    state.should eq(1)
    Fiber.yield
    state.should eq(2)
  end

  it "blocks in receiving when buffer is empty" do
    ch = Channel(Int32).new

    state = 0
    spawn do
      state = 1
      ch.receive
      state = 2
    end

    ch.empty?.should be_true
    Fiber.yield
    state.should eq(1)
    ch.send 123
    Fiber.yield
    state.should eq(2)
  end

  it "deliver many senders" do
    ch = Channel(Int32).new

    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    (1..6).map { ch.receive }.sort.should eq([1, 2, 3, 4, 5, 6])
  end

  it "can send and receive nil" do
    ch = Channel(Nil).new
    spawn { ch.send nil }
    Fiber.yield
    ch.empty?.should be_false
    ch.receive.should be_nil
    ch.empty?.should be_true
  end

  it "can be closed" do
    ch = Channel(Int32).new
    ch.closed?.should be_false
    ch.close.should be_nil
    ch.closed?.should be_true
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "cannot send if closed" do
    ch = Channel(Int32).new
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end
  it "can be closed after sending" do
    ch = Channel(Int32).new
    spawn { ch.send 123; ch.close }
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel(Int32).new
    received = false
    spawn { expect_raises(Channel::ClosedError) { ch.receive }; received = true }
    Fiber.yield
    ch.close
    Fiber.yield
    received.should be_true
  end

  it "can send? when closed" do
    ch = Channel(Int32).new
    ch.close
    ch.send?(123).should be_nil
  end

  it "can receive? when closed" do
    ch = Channel(Int32).new
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel(Int32).new 1
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
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

  it "works with select" do
    ch1 = Channel(Int32).new 1
    ch2 = Channel(Int32).new 1
    ch1.send(123)
    state = 0
    Channel.select do |x|
      x.receive_action ch1 do |val|
        val.should eq(123)
        state = 1
      end

      x.receive_action ch2 do |val|
        state = 2
      end

      x.default_action do
        state = 3
      end
    end
    state.should eq 1
  end

  it "work with select" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "works with select else" do
    ch1 = Channel(Int32).new
    Channel.select({ch1.receive_select_action}, true).should eq({1, nil})
  end

  it "work with select without scheduling duplicate fiber, fixed #3900" do
    ch1 = Channel(Int32).new(1)
    ch2 = Channel(Int32).new(1)
    res = [] of Int32

    spawn do
      loop do
        select
        when x = ch1.receive
          res << x
        when y = ch2.receive
          res << y
        end
      end
    end

    spawn do
      3.times do |i|
        select
        when ch1.send(i)
        when ch2.send(i)
        end
      end
    end

    Fiber.yield
    res.sort.should eq([0, 1, 2])
  end

  it "work with select even changing the spawn order, fixed #3862" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new

    spawn do
      select
      when ch1.send(1)
      when ch2.receive
      end
    end

    x = nil
    spawn do
      select
      when x = ch1.receive
      when ch2.receive
      end
    end

    Fiber.yield
    x.should eq(1)
  end
end
