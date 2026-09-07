require "./spec_helper"
require "sync/mutex_set"

describe Sync::MutexSet do
  it "avoids deadlocks on mutexes given to it in any order" do
    mutexes = Array.new(3) { Sync::Mutex.new }
    mutex_sets = (
      mutexes.permutations(3) +
      mutexes.permutations(2) +
      mutexes.permutations(1)
    ).map do |mutexes|
      Sync::MutexSet.new(mutexes)
    end
    done = Channel(Nil).new
    context = create_context(mutex_sets.size)

    mutex_sets.each do |mutex_set|
      context.spawn do
        # Brute-force and create a lot of contention to cause a deadlock
        100_000.times { mutex_set.synchronize { Fiber.yield } }
      ensure
        done.send nil
      end
    end

    mutex_sets.each do
      select
      when done.receive
      when timeout(30.seconds)
        raise "Deadlock detected"
      end
    end
  end
end

{% if flag?(:execution_context) %}
  private def create_context(size : Int32)
    Fiber::ExecutionContext::Parallel.new("a bunch of work", size)
  end
{% else %}
  private def create_context(size : Int32)
    GlobalContext.new
  end

  struct GlobalContext
    def spawn(&block)
      ::spawn(&block)
    end
  end
{% end %}
