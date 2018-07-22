{% skip_file if flag?(:win32) %}
{% skip_file unless flag?(:darwin) || flag?(:openbsd) %}

require "signal"
require "c/sys/time"

# :nodoc:
class Crystal::System::StdFileDescriptor < IO::FileDescriptor
  @blocking = true

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

    tv = LibC::Itimerval.new

    # FIXME: magical number (1us), must be greater than timer precision, yet
    #        small enough to avoid blocking for too long.
    tv.it_value.tv_usec = 1

    ret = LibC.setitimer(LibC::ITIMER_REAL, pointerof(tv), nil)
    raise Errno.new("setitimer") if ret == -1

    begin
      yield
    ensure
      tv.it_value.tv_usec = 0
      LibC.setitimer(LibC::ITIMER_REAL, pointerof(tv), nil)
    end
  end
end
