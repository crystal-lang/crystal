require "spec"

# These specs are marked as pending until we add
# support for parallelism, where we'll see if we
# need condition variables.
#
# Also: review these specs!
describe Thread::ConditionVariable do
  pending "signals" do
    mutex = Thread::Mutex.new
    cond = Thread::ConditionVariable.new
    pcond = Thread::ConditionVariable.new
    waiting = 0
    signaled = 0

    threads = 3.times.map do
      Thread.new do
        mutex.synchronize do
          waiting += 1
          # TODO: why is this needed? Bug?
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

  pending "broadcasts" do
    mutex = Thread::Mutex.new
    cond = Thread::ConditionVariable.new
    pcond = Thread::ConditionVariable.new
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

  pending "waits and send signal" do
    a = 0
    cv1 = Thread::ConditionVariable.new
    cv2 = Thread::ConditionVariable.new
    m = Thread::Mutex.new

    thread = Thread.new do
      3.times do
        m.synchronize { cv1.wait(m); a += 1; cv2.signal }
      end
    end

    a.should eq(0)
    3.times do |i|
      m.synchronize { cv1.signal; cv2.wait(m) }
      a.should eq(i + 1)
    end

    thread.join
  end
end
