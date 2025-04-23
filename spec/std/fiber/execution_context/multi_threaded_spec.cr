{% skip_file unless flag?(:execution_context) %}
require "spec"

describe Fiber::ExecutionContext::MultiThreaded do
  it ".new" do
    mt = Fiber::ExecutionContext::MultiThreaded.new("test", maximum: 2)
    mt.size.should eq(0)
    mt.capacity.should eq(2)

    expect_raises(ArgumentError, "needs at least one thread") do
      Fiber::ExecutionContext::MultiThreaded.new("test", maximum: -1)
    end

    expect_raises(ArgumentError, "needs at least one thread") do
      Fiber::ExecutionContext::MultiThreaded.new("test", maximum: 0)
    end

    mt = Fiber::ExecutionContext::MultiThreaded.new("test", size: 0..2)
    mt.size.should eq(0)
    mt.capacity.should eq(2)

    mt = Fiber::ExecutionContext::MultiThreaded.new("test", size: ..4)
    mt.size.should eq(0)
    mt.capacity.should eq(4)

    mt = Fiber::ExecutionContext::MultiThreaded.new("test", size: 1..5)
    mt.size.should eq(1)
    mt.capacity.should eq(5)

    mt = Fiber::ExecutionContext::MultiThreaded.new("test", size: 1...5)
    mt.size.should eq(1)
    mt.capacity.should eq(4)

    expect_raises(ArgumentError, "needs at least one thread") do
      Fiber::ExecutionContext::MultiThreaded.new("test", size: 0...1)
    end

    expect_raises(ArgumentError, "invalid range") do
      Fiber::ExecutionContext::MultiThreaded.new("test", size: 5..1)
    end
  end
end
