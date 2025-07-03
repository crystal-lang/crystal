require "./spec_helper"

private def method_with_named_args(chan, x = 1, y = 2)
  chan.send(x + y)
end

private def method_returning_2tuple(x, y)
  {x, y}
end

private def method_returning_3tuple(chan, x = 1, y = 2)
  {chan, x, y}
end

private def method_named(expected_named, chan)
  Fiber.current.name.should eq(expected_named)
  chan.close
end

describe "concurrent" do
  describe "spawn" do
    it "uses spawn macro" do
      chan = Channel(Int32).new

      spawn method_with_named_args(chan)
      chan.receive.should eq(3)

      spawn method_with_named_args(chan, y: 20)
      chan.receive.should eq(21)

      spawn method_with_named_args(chan, x: 10, y: 20)
      chan.receive.should eq(30)

      spawn method_with_named_args(*method_returning_3tuple(chan))
      chan.receive.should eq(3)

      spawn method_with_named_args(*method_returning_3tuple(chan, 30, 40))
      chan.receive.should eq(70)

      spawn method_with_named_args(*method_returning_2tuple(chan, 10))
      chan.receive.should eq(12)

      spawn method_with_named_args(chan, *method_returning_2tuple(10, 20))
      chan.receive.should eq(30)

      spawn method_with_named_args(*method_returning_2tuple(chan, 10), 20)
      chan.receive.should eq(30)
    end

    it "spawns named" do
      chan = Channel(Nil).new
      spawn(name: "sub") do
        Fiber.current.name.should eq("sub")
        chan.close
      end
      chan.receive?
    end

    it "spawns named with macro" do
      chan = Channel(Nil).new
      spawn method_named("foo", chan), name: "foo"
      chan.receive?
    end
  end

  it "accepts method call with receiver" do
    typeof(spawn String.new)
  end

  {% if flag?(:darwin) %}
    pending "schedules intermitting sleeps"
    # TODO: This spec fails on darwin, even with highly increased sleep times. Needs investigation.
  {% else %}
    it "schedules intermitting sleeps" do
      chan = Channel(Int32).new
      spawn do
        3.times do |i|
          sleep 40.milliseconds
          chan.send(i + 1)
        end
      end
      spawn do
        2.times do |i|
          sleep 100.milliseconds
          chan.send (i + 1) * 10
        end
      end

      Array(Int32).new(5) { chan.receive }.should eq [1, 2, 10, 3, 20]
    end
  {% end %}
end
