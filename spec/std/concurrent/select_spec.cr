require "spec"

describe "select" do
  it "select many receviers" do
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

  it "select should work with send which started before receive, fixed #3862" do
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
      when a = ch1.receive
        x = a
      when b = ch2.receive
        x = b
      end
    end

    Fiber.yield

    x.should eq 1
  end
end
