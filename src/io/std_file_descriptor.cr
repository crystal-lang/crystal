{% skip_file if flag?(:win32) %}

require "../signal"
require "c/sys/time"
require "c/time"

# Using `O_NONBLOCK` can lead to unexpected behavior when a file descriptor is
# shared between processes, which is always the case for `STDIN`, `STDOUT` and
# `STDERR`. Other processes may not be resilient to file descriptors having
# `O_NONBLOCK` set and may even change it to return back to blocking —which can
# happen when spawning a child process that inherits STDIN for example.
#
# A solution (hack) is to have blocking syscalls but arm timers to send the ALRM
# signal that will cause blocking syscalls to fail and return EINTR.
#
# WARNING: this affects all interuptible syscalls! See `signal(7)` for the full
# list.
#
# See:
# - https://github.com/crystal-lang/crystal/issues/3674
# - http://cr.yp.to/unix/nonblock.html

# :nodoc:
class IO::StdFileDescriptor < IO::FileDescriptor
  @blocking = true

  def blocking=(@blocking)
    # Never set O_NONBLOCK on standard file descriptors! See:
  end

  def blocking?
    @blocking
  end

  def read_syscall_helper(slice : Bytes, errno_msg : String)
    super(slice, errno_msg) do
      with_timer do
        yield slice
      end
    end
  end

  def write_syscall_helper(slice : Bytes, errno_msg : String)
    super(slice, errno_msg) do |part|
      with_timer do
        yield part
      end
    end
  end

  private def with_timer
    return yield if blocking?

    {% if flag?(:darwin) || flag?(:openbsd) %}
      tv = LibC::Itimerval.new
      tv.it_value.tv_usec = 1

      ret = LibC.setitimer(LibC::ITIMER_REAL, pointerof(tv), nil)
      raise Errno.new("setitimer") if ret == -1

      begin
        yield
      ensure
        tv.it_value.tv_usec = 0
        LibC.setitimer(LibC::ITIMER_REAL, pointerof(tv), nil)
      end
    {% else %}
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
    {% end %}
  end

  {% unless flag?(:darwin) || flag?(:openbsd) %}
    @timer_id : LibC::TimerT?

    private def timer_id
      @timer_id ||= begin
        ret = LibC.timer_create(LibC::CLOCK_MONOTONIC, nil, out timer_id)
        raise Errno.new("timer_create") if ret == -1
        timer_id
      end
    end
  {% end %}
end
