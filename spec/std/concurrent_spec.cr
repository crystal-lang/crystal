require "./spec_helper"

private def method_with_named_args(chan, x = 1, y = 2)
  chan.send(x + y)
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
end
