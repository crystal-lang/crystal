require "../spec_helper"
require "wait_group"

module Sync
  class Error::Deadlock
    def_equals message, fiber1, fiber2, lock1, lock2
  end

  def self.expect_deadlock(ex, f1, f2, l1, l2)
    if ex.is_a?(Sync::Error::Deadlock)
      ex.should eq Sync::Error.deadlock(f1, f2, l1, l2)
    else
      raise ex
    end
  end

  def self.eventually(timeout : Time::Span = 1.second, &)
    start = Time.instant

    loop do
      Fiber.yield

      begin
        yield
      rescue ex
        raise ex if start.elapsed > timeout
      else
        break
      end
    end
  end

  def self.async(name = nil, &block) : Nil
    done = false
    exception = nil

    spawn(name: name) do
      block.call
    rescue ex
      exception = ex
    ensure
      done = true
    end

    eventually { done.should be_true, "Expected async fiber to have finished" }

    if ex = exception
      raise ex
    end
  end

  def self.async_channel(name = nil, &block)
    channel = Channel(Exception).new

    fiber = spawn(name: name) do
      block.call
    rescue ex
      channel.send(ex)
    end

    {fiber, channel}
  end

  def self.timeout(name = nil, &block)
    _, channel = async_channel(name, &block)

    select
    when ex = channel.receive
      raise ex if ex
    when timeout(1.second)
      fail "timeout: didn't complete in 1.second"
    end
  end

  module FakeContext
    def self.spawn(*, name : String? = nil, &block : ->) : Fiber
      ::spawn(name: name, &block)
    end
  end

  CONCURRENT =
    {% if Fiber.has_constant?(:ExecutionContext) %}
      ctx = Fiber::ExecutionContext.current
      if ctx.is_a?(Fiber::ExecutionContext::Parallel) && ctx.capacity > 1
        ctx = Fiber::ExecutionContext::Concurrent.new("CONCURRENT")
      end
      ctx
    {% else %}
      FakeContext
    {% end %}
end
