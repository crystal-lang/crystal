{% skip_file unless flag?(:linux) %}

require "./io_uring"

# :nodoc:
struct Crystal::IoUringEvent < Crystal::Event
  enum Type
    Resume
    Timeout
    ReadableFd
    WritableFd
  end

  def initialize(@io_uring : Crystal::System::IoUring, @type : Type, @fd : Int32, &callback : Int32 ->)
    @callback = Box.box(callback)
  end

  def free : Nil
  end

  def delete : Nil
    if @type.timeout?
      @io_uring.timeout_remove(@callback)
    end
  end

  def add(timeout : Time::Span?) : Nil
    timeout = nil if timeout == Time::Span::ZERO

    case @type
    in .resume?, .timeout?
      if timeout
        @io_uring.timeout(timeout, @callback)
      else
        @io_uring.nop(@callback)
      end
    in .readable_fd?
      @io_uring.wait_readable(@fd, @callback, timeout: timeout)
    in .writable_fd?
      @io_uring.wait_writable(@fd, @callback, timeout: timeout)
    end
  end
end
