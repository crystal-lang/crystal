require "./spec_helper"
require "../support/thread"

{% if flag?(:win32) %}
  private lib LibThreadSpec
    fun GetHandleInformation(hObject : LibC::HANDLE, lpdwFlags : LibC::DWORD*) : LibC::BOOL
  end
{% end %}

# interpreter doesn't support threads yet (#14287)
pending_interpreted describe: Thread do
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

  {% if flag?(:win32) %}
    it "closes its semaphore when joined before exiting" do
      thread = Thread.new do |current|
        deadline = Time.instant + 2.seconds
        # Keep the worker alive until join claims the detach gate.
        until current.@detached.get
          raise "Thread was not joined in time" if Time.instant >= deadline
          Thread.sleep(1.millisecond)
        end
      end
      semaphore = thread.@semaphore
      before_join = LibThreadSpec.GetHandleInformation(semaphore, out flags)
      thread.join
      after_join = LibThreadSpec.GetHandleInformation(semaphore, pointerof(flags))
      error = WinError.value

      before_join.should_not eq(0)
      after_join.should eq(0)
      error.should eq(WinError::ERROR_INVALID_HANDLE)
    end
  {% end %}

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

  it "names the thread" do
    {% if Fiber.has_constant?(:ExecutionContext) %}
      Thread.current.name.should match(/DEFAULT-\d+/)
    {% else %}
      Thread.current.name.should be_nil
    {% end %}

    name = nil
    thread = Thread.new(name: "some-name") do
      name = Thread.current.name
    end
    thread.name.should eq("some-name")

    thread.join
    name.should eq("some-name")
  end
end
