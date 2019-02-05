require "spec"

private def yield_to(fiber)
  Crystal::Scheduler.enqueue(Fiber.current)
  Crystal::Scheduler.resume(fiber)
end

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
    res = [] of Int32
    spawn do
      5.times { res << ch1.receive }
    end

    spawn do
      5.times { res << ch2.receive }
    end

    10.times do |i|
      select
      when ch1.send(i)
      when ch2.send(i)
      end
    end
    res.should eq (0...10).to_a
  end

  it "select many receivers, senders" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    res = [] of Int32
    spawn do
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
    res.should eq (0...10).to_a
  end

  it "select else clause and cancel other clauses" do
    ch1 = Channel::Buffered(Int32).new(1)
    ch2 = Channel::Buffered(Int32).new(1)

    select
    when ch1.receive
      got = 1
    when ch2.receive
      got = 2
    else
      got = -1
    end

    got.should eq(-1)

    spawn do
      ch1.send(1)
      ch2.send(2)
      ch1.close
      ch2.close
    end

    ch1.receive.should eq(1)
    ch1.receive?.should be_nil

    ch2.receive.should eq(2)
    ch2.receive?.should be_nil
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
      yield_to(main)
    end

    sleep
    x.should eq 1
  end

  it "won't enqueue a dead/running fiber, fixed #3900" do
    ch = Channel::Buffered(Int32).new(1)

    spawn do
      ch.send(1)

      select
      when ch.send(1)
      when ch.send(2)
      end

      ch.close
    end

    ch.receive.should eq(1)
    ch.receive.should eq(1)
    ch.receive?.should be_nil
  end
end
