{% skip_file unless flag?(:execution_context) %}
require "spec"

describe Fiber::ExecutionContext::Parallel do
  it ".new" do
    mt = Fiber::ExecutionContext::Parallel.new("test", maximum: 2)
    mt.size.should eq(0)
    mt.capacity.should eq(2)

    expect_raises(ArgumentError, "Parallelism can't be less than one") do
      Fiber::ExecutionContext::Parallel.new("test", maximum: -1)
    end

    expect_raises(ArgumentError, "Parallelism can't be less than one") do
      Fiber::ExecutionContext::Parallel.new("test", maximum: 0)
    end

    # the following are deprecated constructors

    mt = Fiber::ExecutionContext::Parallel.new("test", size: 0..2)
    mt.size.should eq(0)
    mt.capacity.should eq(2)

    mt = Fiber::ExecutionContext::Parallel.new("test", size: ..4)
    mt.size.should eq(0)
    mt.capacity.should eq(4)

    mt = Fiber::ExecutionContext::Parallel.new("test", size: 1..5)
    mt.size.should eq(0)
    mt.capacity.should eq(5)

    mt = Fiber::ExecutionContext::Parallel.new("test", size: 1...5)
    mt.size.should eq(0)
    mt.capacity.should eq(4)

    expect_raises(ArgumentError, "Parallelism can't be less than one.") do
      Fiber::ExecutionContext::Parallel.new("test", size: 0...1)
    end

    expect_raises(ArgumentError, "invalid range") do
      Fiber::ExecutionContext::Parallel.new("test", size: 5..1)
    end
  end
end
