require "../signal"
require "c/time"

class IO::StdFileDescriptor < IO::FileDescriptor
  @read_timer_id : LibC::TimerT
  @write_timer_id : LibC::TimerT
  @blocking = true

  def initialize(fd, blocking = false)
    ret = LibC.timer_create(LibC::CLOCK_MONOTONIC, nil, out @read_timer_id)
    raise Errno.new("timer_create") if ret == -1

    ret = LibC.timer_create(LibC::CLOCK_MONOTONIC, nil, out @write_timer_id)
    raise Errno.new("timer_create") if ret == -1

    super(fd, blocking)
  end

  def blocking=(@blocking)
    # Never set O_NONBLOCK on standard file descriptors! See:
    # - https://github.com/crystal-lang/crystal/issues/3674
    # - http://cr.yp.to/unix/nonblock.html
  end

  def blocking?
    @blocking
  end

  def read_syscall_helper(slice : Bytes, errno_msg : String)
    super(slice, errno_msg) do
      with_timer(@read_timer_id) do
        yield slice
      end
    end
  end

  def write_syscall_helper(slice : Bytes, errno_msg : String)
    super(slice, errno_msg) do |part|
      with_timer(@write_timer_id) do
        yield part
      end
    end
  end

  private def with_timer(timer_id)
    return yield if blocking?

    ts = LibC::Itimerspec.new

    # FIXME: magical number (1us), must be greater than timer precision, yet
    #        small enough to avoid blocking for too long...
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
end
