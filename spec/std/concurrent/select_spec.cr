require "spec"
require "../spec_helper"

describe "select" do
  it "select many receivers" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    res = [] of Int32
    spawn do
      10.times do |i|
        (i % 2 == 0) ? ch1.send(i) : ch2.send(i)
      end
    end

    10.times do
      select
      when x = ch1.receive
        res << x
      when y = ch2.receive
        res << y
      end
    end
    res.should eq (0...10).to_a
  end

  it "select many senders" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    res = Array.new(10, 0)

    f1 = spawn do
      5.times { res[ch1.receive] = 1 }
    end

    f2 = spawn do
      5.times { res[ch2.receive] = 1 }
    end

    10.times do |i|
      select
      when ch1.send(i)
      when ch2.send(i)
      end
    end

    until f1.dead? && f2.dead?
      Fiber.yield
    end

    res.should eq Array.new(10, 1)
  end

  it "select many receivers, senders" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    res = [] of Int32
    f = spawn do
      10.times do |i|
        select
        when x = ch1.receive
          res << x
        when ch2.send(i)
        end
      end
    end

    10.times do |i|
      select
      when ch1.send(i)
      when y = ch2.receive
        res << y
      end
    end

    wait_until_finished f

    res.should eq (0...10).to_a
  end

  it "select should work with send which started before receive, fixed #3862" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    main = Fiber.current

    spawn do
      select
      when ch1.send(1)
      when ch2.receive
      end
    end

    x = nil

    spawn do
      select
      when a = ch1.receive
        x = a
      when b = ch2.receive
        x = b
      end
    ensure
      Crystal::Scheduler.enqueue(main)
    end

    sleep
    x.should eq 1
  end

  it "select fiber has one chance to be enqueued into scheduler (1)" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    ch3 = Channel(Int32).new
    x = nil

    f = spawn do
      select
      when x = ch1.receive
      when x = ch2.receive
      end
    end

    spawn do
      ch1.send 1
      ch3.send 3
      ch2.close
    end

    ch3.receive.should eq(3)
    wait_until_finished f
    x.should eq(1)
  end

  it "select fiber has one chance to be enqueued into scheduler (2)" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    ch3 = Channel(Int32).new
    x = nil

    f = spawn do
      select
      when ch1.send 1
        x = 1
      when ch2.send 2
        x = 2
      end
    end

    spawn do
      ch1.receive
      ch3.send 3
      ch2.close
    end

    ch3.receive.should eq(3)
    wait_until_finished f
    x.should eq(1)
  end

  it "select same channel multiple times" do
    ch = Channel(Int32).new

    spawn do
      ch.send(123)
    end

    select
    when ch.send(456)
    when x = ch.receive
    end

    x.should eq 123
  end

  it "prioritize by order when entering in a select" do
    ch1 = Channel(Int32).new(5)
    ch2 = Channel(Int32).new(5)

    2.times { ch1.send 1 }
    2.times { ch2.send 2 }

    select
    when x = ch1.receive
    when x = ch2.receive
    end
    x.should eq 1

    select
    when x = ch2.receive
    when x = ch1.receive
    end
    x.should eq 2
  end

  it "stress select with send/receive in multiple fibers" do
    fibers = 4
    msg_per_sender = 1000
    ch = Array.new(fibers) { Array.new(fibers) { Channel(Int32).new } }
    done = Channel({Int32, Int32}).new

    fibers.times do |i|
      spawn(name: "sender #{i}") do
        channels = ch[i]
        msg_per_sender.times do |i|
          Channel.send_first(i, channels)
        end
        channels.map &.send(-1)
      end
    end

    fibers.times do |i|
      spawn(name: "receiver #{i}") do
        channels = ch.map { |chs| chs[i] }
        closed = 0
        count = 0
        sum = 0
        loop do
          x = Channel.receive_first(channels).not_nil!
          if x == -1
            closed += 1
            break if closed == fibers
          else
            count += 1
            sum += x
          end
        end
        done.send({count, sum})
      end
    end

    count = 0
    sum = 0
    fibers.times do
      c, s = done.receive
      count += c
      sum += s
    end

    count.should eq(fibers * msg_per_sender)
    sum.should eq(msg_per_sender * (msg_per_sender - 1) / 2 * fibers)
  end

  context "blocking raise-on-close single-channel" do
    it "types and exec when" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive
          w.check
          typeof(m).should eq(String)
          m.should eq("foo")
        end
      end
    end

    it "raises if channel was closed" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.close }) do |w|
        begin
          select
          when m = ch.receive
          end
        rescue Channel::ClosedError
          w.check
        end
      end
    end
  end

  context "non-blocking raise-on-close single-channel" do
    it "types and exec when if message was ready" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive
          w.check
          typeof(m).should eq(String)
          m.should eq("foo")
        else
        end
      end
    end

    it "exec else if no message was ready" do
      ch = Channel(String).new

      spawn_and_check(->{ nil }) do |w|
        select
        when m = ch.receive
        else
          w.check
        end
      end
    end

    it "raises if channel was closed" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.close }) do |w|
        begin
          select
          when m = ch.receive
          else
          end
        rescue Channel::ClosedError
          w.check
        end
      end
    end
  end

  context "blocking raise-on-close multi-channel" do
    it "types and exec when (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive
          w.check
          typeof(m).should eq(String)
          m.should eq("foo")
        when m = ch2.receive
        end
      end
    end

    it "types and exec when (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.send true }) do |w|
        select
        when m = ch.receive
        when m = ch2.receive
          w.check
          typeof(m).should eq(Bool)
          m.should eq(true)
        end
      end
    end

    it "raises if channel was closed (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.close }) do |w|
        begin
          select
          when m = ch.receive
          when m = ch2.receive
          end
        rescue Channel::ClosedError
          w.check
        end
      end
    end

    it "raises if channel was closed (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.close }) do |w|
        begin
          select
          when m = ch.receive
          when m = ch2.receive
          end
        rescue Channel::ClosedError
          w.check
        end
      end
    end
  end

  context "non-blocking raise-on-close multi-channel" do
    it "types and exec when (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive
          w.check
          typeof(m).should eq(String)
          m.should eq("foo")
        when m = ch2.receive
        else
        end
      end
    end

    it "types and exec when (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.send true }) do |w|
        select
        when m = ch.receive
        when m = ch2.receive
          w.check
          typeof(m).should eq(Bool)
          m.should eq(true)
        else
        end
      end
    end

    it "exec else if no message was ready" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ nil }) do |w|
        select
        when m = ch.receive
        when m = ch2.receive
        else
          w.check
        end
      end
    end

    it "raises if channel was closed (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.close }) do |w|
        begin
          select
          when m = ch.receive
          when m = ch2.receive
          else
          end
        rescue Channel::ClosedError
          w.check
        end
      end
    end

    it "raises if channel was closed (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.close }) do |w|
        begin
          select
          when m = ch.receive
          when m = ch2.receive
          else
          end
        rescue Channel::ClosedError
          w.check
        end
      end
    end
  end

  context "blocking nil-on-close single-channel" do
    it "types and exec when" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should eq("foo")
        end
      end
    end

    it "types and exec when with nil if channel was closed" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.close }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should be_nil
        end
      end
    end
  end

  context "blocking nil-on-close multi-channel" do
    it "types and exec when (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should eq("foo")
        when m = ch2.receive?
        end
      end
    end

    it "types and exec when (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.send true }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
          w.check
          typeof(m).should eq(Bool?)
          m.should eq(true)
        end
      end
    end

    it "types and exec when with nil if channel was closed (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.close }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should be_nil
        when m = ch2.receive?
        end
      end
    end

    it "types and exec when with nil if channel was closed (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.close }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
          w.check
          typeof(m).should eq(Bool?)
          m.should be_nil
        end
      end
    end

    it "types and exec when with nil if channel is closed while waiting (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.close }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should be_nil
        when m = ch2.receive?
        end
      end
    end

    it "types and exec when with nil if channel is closed while waiting (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.close }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
          w.check
          typeof(m).should eq(Bool?)
          m.should be_nil
        end
      end
    end
  end

  context "non-blocking nil-on-close single-channel" do
    it "types and exec when" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should eq("foo")
        else
        end
      end
    end

    it "exec else if no message was ready" do
      ch = Channel(String).new

      spawn_and_check(->{ nil }) do |w|
        select
        when m = ch.receive?
        else
          w.check
        end
      end
    end

    it "types and exec when with nil if channel was closed" do
      ch = Channel(String).new

      spawn_and_check(->{ ch.close }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should be_nil
        else
        end
      end
    end
  end

  context "non-blocking nil-on-close multi-channel" do
    it "types and exec when (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.send "foo" }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should eq("foo")
        when m = ch2.receive?
        else
        end
      end
    end

    it "types and exec when (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.send true }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
          w.check
          typeof(m).should eq(Bool?)
          m.should eq(true)
        else
        end
      end
    end

    it "types and exec when with nil if channel was closed (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.close }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should be_nil
        when m = ch2.receive?
        else
        end
      end
    end

    it "types and exec when with nil if channel was closed (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.close }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
          w.check
          typeof(m).should eq(Bool?)
          m.should be_nil
        else
        end
      end
    end

    it "types and exec when with nil if channel is closed while waiting (1)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch.close }) do |w|
        select
        when m = ch.receive?
          w.check
          typeof(m).should eq(String?)
          m.should be_nil
        when m = ch2.receive?
        else
        end
      end
    end

    it "types and exec when with nil if channel is closed while waiting (2)" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ ch2.close }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
          w.check
          typeof(m).should eq(Bool?)
          m.should be_nil
        else
        end
      end
    end

    it "exec else if no message was ready" do
      ch = Channel(String).new
      ch2 = Channel(Bool).new

      spawn_and_check(->{ nil }) do |w|
        select
        when m = ch.receive?
        when m = ch2.receive?
        else
          w.check
        end
      end
    end
  end
end
