{% skip_file unless flag?(:execution_context) %}
require "spec"
require "wait_group"

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

  it "#resize" do
    ctx = Fiber::ExecutionContext::Parallel.new("ctx", 1)
    running = Atomic(Bool).new(true)
    wg = WaitGroup.new

    10.times do
      wg.add(1)

      ctx.spawn do
        while running.get(:relaxed)
          sleep(10.microseconds)
        end
      ensure
        wg.done
      end
    end

    # it grows
    ctx.resize(4)
    ctx.capacity.should eq(4)

    # it shrinks
    ctx.resize(2)
    ctx.capacity.should eq(2)

    # it doesn't change
    ctx.resize(2)
    ctx.capacity.should eq(2)

    10.times do
      n = rand(1..4)
      ctx.resize(n)
      ctx.capacity.should eq(n)
    end

    running.set(false)
    wg.wait
  end
end
