{% skip_file unless Fiber.has_constant?(:ExecutionContext) %}
require "../../spec_helper"
require "../../../support/wait_for"

private class InjectedParkedWaitError < Exception
end

module Crystal
  @@thread_pool_error_reports = Atomic(Int32).new(0)

  def self.thread_pool_error_reports
    @@thread_pool_error_reports.get(:relaxed)
  end

  def self.reset_thread_pool_error_reports
    @@thread_pool_error_reports.set(0, :relaxed)
  end

  def self.print_error_buffered(message : String, *args, exception = nil, backtrace = nil) : Nil
    if exception.is_a?(InjectedParkedWaitError)
      @@thread_pool_error_reports.add(1, :relaxed)
    else
      previous_def(message, *args, exception: exception, backtrace: backtrace)
    end
  end
end

module Fiber::ExecutionContext
  def self.thread_pool_for_spec=(@@thread_pool)
  end
end

class Fiber::ExecutionContext::ThreadPool
  def enter_thread_loop_for_spec(thread)
    enter_thread_loop(thread)
  end

  def empty_for_spec?
    @mutex.synchronize { @pool.empty? }
  end

  def wake_for_spec
    parked = @mutex.synchronize { @pool.shift? }.not_nil!
    parked.value.synchronize { parked.value.wake }
  end

  struct Parked
    enum WaitAction
      Wait
      Raise
    end

    class_property wait_action : (self -> WaitAction)?

    def wait(timeout, &)
      case @@wait_action.try &.call(self)
      when WaitAction::Raise
        raise InjectedParkedWaitError.new("injected parked wait failure")
      else
        previous_def(timeout) { yield }
      end
    end
  end
end

class Fiber::ExecutionContext::Isolated
  def thread_for_spec
    @thread
  end
end

describe Fiber::ExecutionContext::ThreadPool do
  after_each do
    Fiber::ExecutionContext::ThreadPool::Parked.wait_action = nil
    Crystal.reset_thread_pool_error_reports
  end

  it "stops after three consecutive wait failures and removes the parked thread" do
    pool = Fiber::ExecutionContext::ThreadPool.new
    attempts = Atomic(Int32).new(0)
    done = Atomic(Bool).new(false)
    target_id = Atomic(UInt64).new(0)

    Fiber::ExecutionContext::ThreadPool::Parked.wait_action = ->(_parked : Fiber::ExecutionContext::ThreadPool::Parked) do
      if Thread.current.object_id == target_id.get(:acquire)
        attempts.add(1, :relaxed)
        Fiber::ExecutionContext::ThreadPool::Parked::WaitAction::Raise
      else
        Fiber::ExecutionContext::ThreadPool::Parked::WaitAction::Wait
      end
    end

    thread = Thread.new do
      target_id.set(Thread.current.object_id, :release)
      pool.enter_thread_loop_for_spec(Thread.current)
    ensure
      done.set(true, :release)
    end

    finished = wait_for(5.seconds) { done.get(:acquire) }
    attempts.get(:relaxed).should eq(3)
    Crystal.thread_pool_error_reports.should eq(3)
    finished.should be_true
    thread.join

    pool.empty_for_spec?.should be_true
  end

  it "resets the failure count after a successful park and wakeup" do
    pool = Fiber::ExecutionContext::ThreadPool.new
    attempts = Atomic(Int32).new(0)
    done = Atomic(Bool).new(false)
    target_id = Atomic(UInt64).new(0)

    Fiber::ExecutionContext::ThreadPool::Parked.wait_action = ->(_parked : Fiber::ExecutionContext::ThreadPool::Parked) do
      if Thread.current.object_id != target_id.get(:acquire)
        Fiber::ExecutionContext::ThreadPool::Parked::WaitAction::Wait
      else
        case attempts.add(1, :relaxed)
        when 0
          Fiber::ExecutionContext::ThreadPool::Parked::WaitAction::Raise
        when 1
          Fiber::ExecutionContext::ThreadPool::Parked::WaitAction::Wait
        else
          Fiber::ExecutionContext::ThreadPool::Parked::WaitAction::Raise
        end
      end
    end

    thread = Thread.new do
      target_id.set(Thread.current.object_id, :release)
      pool.enter_thread_loop_for_spec(Thread.current)
    ensure
      done.set(true, :release)
    end

    wait_for(5.seconds) { attempts.get(:relaxed) == 2 && !pool.empty_for_spec? }.should be_true
    pool.wake_for_spec
    wait_for(5.seconds) { done.get(:acquire) }.should be_true
    thread.join

    attempts.get(:relaxed).should eq(5)
    Crystal.thread_pool_error_reports.should eq(4)
    pool.empty_for_spec?.should be_true
  end

  it "checks a thread out, runs its scheduler, and returns it to the pool" do
    original_pool = Fiber::ExecutionContext.thread_pool
    original_keepalive = Fiber::ExecutionContext.thread_keepalive
    pool = Fiber::ExecutionContext::ThreadPool.new
    Fiber::ExecutionContext.thread_pool_for_spec = pool
    Fiber::ExecutionContext.thread_keepalive = 1.millisecond

    ran = Atomic(Bool).new(false)
    context = Fiber::ExecutionContext::Isolated.new("THREAD-POOL-SPEC") do
      ran.set(true, :release)
    end
    thread = context.thread_for_spec

    context.wait
    thread.join

    ran.get(:acquire).should be_true
    Crystal.thread_pool_error_reports.should eq(0)
    pool.empty_for_spec?.should be_true
  ensure
    Fiber::ExecutionContext.thread_pool_for_spec = original_pool.not_nil!
    Fiber::ExecutionContext.thread_keepalive = original_keepalive.not_nil!
  end
end
