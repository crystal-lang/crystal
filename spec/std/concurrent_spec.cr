require "spec"

private def method_with_named_args(chan, x = 1, y = 2)
  chan.send(x + y)
end

describe "concurrent" do
  it "does four things concurrently" do
    a, b, c, d = parallel(1 + 2, "hello".size, [1, 2, 3, 4].size, nil)
    a.should eq(3)
    b.should eq(5)
    c.should eq(4)
    d.should be_nil
  end

  it "uses spawn macro" do
    chan = Channel(Int32).new

    spawn method_with_named_args(chan)
    chan.receive.should eq(3)

    spawn method_with_named_args(chan, y: 20)
    chan.receive.should eq(21)

    spawn method_with_named_args(chan, x: 10, y: 20)
    chan.receive.should eq(30)
  end
end
