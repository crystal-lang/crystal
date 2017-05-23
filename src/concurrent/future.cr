# :nodoc:
class Concurrent::Future(R)
  enum State
    Idle
    Delayed
    Running
    Completed
    Canceled
  end

  @value : R?
  @error : Exception?
  @delay : Float64

  def initialize(run_immediately = true, delay = 0.0, &@block : -> R)
    @state = State::Idle
    @value = nil
    @error = nil
    @channel = Channel(Nil).new
    @delay = delay.to_f
    @cancel_msg = nil

    spawn_compute if run_immediately
  end

  def get
    wait
    value_or_raise
  end

  def success?
    completed? && !@error
  end

  def failure?
    completed? && @error
  end

  def canceled?
    @state == State::Canceled
  end

  def completed?
    @state == State::Completed
  end

  def running?
    @state == State::Running
  end

  def delayed?
    @state == State::Delayed
  end

  def idle?
    @state == State::Idle
  end

  def cancel(msg = "Future canceled, you reached the [End of Time]")
    return if @state >= State::Completed
    @state = State::Canceled
    @cancel_msg = msg
    @channel.close
    nil
  end

  private def compute
    return if @state >= State::Delayed
    run_compute
  end

  private def spawn_compute
    return if @state >= State::Delayed

    @state = @delay > 0 ? State::Delayed : State::Running

    spawn { run_compute }
  end

  private def run_compute
    delay = @delay

    if delay > 0
      sleep delay
      return if @state >= State::Canceled
      @state = State::Running
    end

    begin
      @value = @block.call
    rescue ex
      @error = ex
    ensure
      @channel.close
      @state = State::Completed
    end
  end

  private def wait
    return if @state >= State::Completed
    compute
    @channel.receive?
  end

  private def value_or_raise
    raise Concurrent::CanceledError.new(@cancel_msg) if @state == State::Canceled

    value = @value
    if value.is_a?(R)
      value
    elsif error = @error
      raise error
    else
      raise "Compiler bug"
    end
  end
end

# Spawns a `Fiber` to compute *&block* in the background after *delay* has elapsed.
# Access to get is synchronized between fibers.  *&block* is only called once.
# May be canceled before *&block* is called by calling `cancel`.
# ```
# d = delay(1) { Process.kill(Signal::KILL, Process.pid) }
# # ... long operations ...
# d.cancel
# ```
def delay(delay, &block : -> _)
  Concurrent::Future.new delay: delay, &block
end

# Spawns a `Fiber` to compute *&block* in the background.
# Access to get is synchronized between fibers.  *&block* is only called once.
# ```
# f = future { `echo hello` }
# # ... other actions ...
# f.get # => "hello\n"
# ```
def future(&exp : -> _)
  Concurrent::Future.new &exp
end

# Conditionally spawns a `Fiber` to run *&block* in the background.
# Access to get is synchronized between fibers.  *&block* is only called once.
# *&block* doesn't run by default, only when `get` is called.
# ```
# l = lazy { expensive_computation }
# spawn { maybe_use_computation(l) }
# spawn { maybe_use_computation(l) }
# ```
def lazy(&block : -> _)
  Concurrent::Future.new run_immediately: false, &block
end
