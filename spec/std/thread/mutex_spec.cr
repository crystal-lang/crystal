{% if flag?(:musl) %}
  # FIXME: These thread specs occasionally fail on musl/alpine based ci, so
  # they're disabled for now to reduce noise.
  # See https://github.com/crystal-lang/crystal/issues/8738
  pending Thread::Mutex
  {% skip_file %}
{% end %}

require "spec"

describe Thread::Mutex do
  it "synchronizes" do
    a = 0
    mutex = Thread::Mutex.new

    threads = 10.times.map do
      Thread.new do
        mutex.synchronize { a += 1 }
      end
    end.to_a

    threads.each(&.join)
    a.should eq(10)
  end

  it "won't lock recursively" do
    mutex = Thread::Mutex.new
    mutex.try_lock.should be_true
    mutex.try_lock.should be_false
    expect_raises(RuntimeError, "pthread_mutex_lock: ") { mutex.lock }
    mutex.unlock
  end

  it "won't unlock from another thread" do
    mutex = Thread::Mutex.new
    mutex.lock

    expect_raises(RuntimeError, "pthread_mutex_unlock: ") do
      Thread.new { mutex.unlock }.join
    end

    mutex.unlock
  end
end
