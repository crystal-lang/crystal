require "spec"

describe ConditionVariable do
  it "signals" do
    mutex = Mutex.new
    cond = ConditionVariable.new
    pcond = ConditionVariable.new
    waiting = 0
    signaled = 0

    threads = 3.times.map do
      Thread.new do
        mutex.synchronize do
          waiting += 1
          pcond.signal
          cond.wait mutex
        end
      end
    end.to_a

    while signaled < 3
      mutex.synchronize do
        if waiting > 0
          waiting -= 1
          signaled += 1
          cond.signal
        end
      end
    end
    threads.map &.join
  end

  it "broadcasts" do
    mutex = Mutex.new
    cond = ConditionVariable.new
    pcond = ConditionVariable.new
    waiting = 0
    signaled = false

    threads = 3.times.map do
      Thread.new do
        mutex.synchronize do
          waiting += 1
          pcond.signal
          cond.wait mutex
        end
      end
    end.to_a

    until signaled
      mutex.synchronize do
        if waiting >= 3
          cond.broadcast
          signaled = true
        else
          pcond.wait mutex
        end
      end
    end

    threads.map &.join
  end
end
