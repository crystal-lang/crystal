{% skip_file if flag?(:win32) || flag?(:darwin) || flag?(:openbsd) %}

require "signal"
require "c/sys/time"
require "c/time"

# :nodoc:
class Crystal::System::StdFileDescriptor < IO::FileDescriptor
  @blocking = true
  @timer_id : LibC::TimerT?

  def blocking=(@blocking)
    # Never set O_NONBLOCK on standard file descriptors!
  end

  def blocking?
    @blocking
  end

  def read_syscall_helper(slice : Bytes, errno_msg : String)
    super(slice, errno_msg) do
      with_timer { yield slice }
    end
  end

  def write_syscall_helper(slice : Bytes, errno_msg : String)
    super(slice, errno_msg) do |part|
      with_timer { yield part }
    end
  end

  private def with_timer
    return yield if blocking?

    ts = LibC::Itimerspec.new

    # FIXME: magical number (1us), must be greater than timer precision, yet
    #        small enough to avoid blocking for too long.
    ts.it_value.tv_nsec = 1_000

    ret = LibC.timer_settime(timer_id, 0, pointerof(ts), nil)
    raise Errno.new("timer_settime") if ret == -1

    begin
      yield
    ensure
      ts.it_value.tv_nsec = 0
      LibC.timer_settime(timer_id, 0, pointerof(ts), nil)
    end
  end

  private def timer_id
    @timer_id ||= begin
      ret = LibC.timer_create(LibC::CLOCK_MONOTONIC, nil, out timer_id)
      raise Errno.new("timer_create") if ret == -1
      timer_id
    end
  end
end
