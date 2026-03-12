require "../spec_helper"
require "wait_group"

module Sync
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

  def self.async(&block) : Nil
    done = false
    exception = nil

    spawn do
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

  module FakeContext
    def self.spawn(*, name : String? = nil, &block : ->) : Fiber
      ::spawn(name: name, &block)
    end
  end

  CONCURRENT =
    {% if flag?(:execution_context) %}
      ctx = Fiber::ExecutionContext.current
      if ctx.is_a?(Fiber::ExecutionContext::Parallel) && ctx.capacity > 1
        ctx = Fiber::ExecutionContext::Concurrent.new("CONCURRENT")
      end
      ctx
    {% else %}
      FakeContext
    {% end %}
end
