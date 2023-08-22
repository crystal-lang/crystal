require "spec"

{% if flag?(:musl) %}
  # FIXME: These thread specs occasionally fail on musl/alpine based ci, so
  # they're disabled for now to reduce noise.
  # See https://github.com/crystal-lang/crystal/issues/8738
  pending Thread
  {% skip_file %}
{% end %}

describe Thread do
  it "allows passing an argumentless fun to execute" do
    a = 0
    thread = Thread.new { a = 1; 10 }
    thread.join
    a.should eq(1)
  end

  it "raises inside thread and gets it on join" do
    thread = Thread.new { raise "OH NO" }
    expect_raises Exception, "OH NO" do
      thread.join
    end
  end

  it "returns current thread object" do
    current = nil
    thread = Thread.new { current = Thread.current }
    thread.join
    current.should be(thread)
    current.should_not be(Thread.current)
  ensure
    # avoids a "GC Warning: Finalization cycle" caused by *current*
    # referencing the thread itself, preventing the finalizer to run:
    current = nil
  end

  it "yields the processor" do
    done = false

    thread = Thread.new do
      3.times { Thread.yield }
      done = true
    end

    until done
      Thread.yield
    end

    thread.join
  end
end
