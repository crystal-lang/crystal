require "./io_uring"

# :nodoc:
struct Crystal::IoUring::Event < Crystal::EventLoop::Event
  enum Type
    Resume
    Timeout
    ReadableFd
    WritableFd
  end

  def initialize(@io_uring : Crystal::System::IoUring, @type : Type, @fd : Int32 = -1, &@callback : Int32 ->)
    @action_id = 0u64
  end

  def free : Nil
    delete
  end

  def delete : Nil
    return if @action_id == 0u64
    @io_uring.delete_completion_action(@action_id)
    if @type.timeout?
      @io_uring.submit_timeout_remove(@action_id)
    end
    @action_id = 0u64
  end

  def add(timeout : Time::Span?) : Nil
    delete
    @action_id = @io_uring.register_completion_action(@callback)

    timeout = nil if timeout == Time::Span::ZERO

    case @type
    in .resume?, .timeout?
      if timeout
        @io_uring.submit_timeout(timeout, action_id: @action_id)
      else
        @io_uring.submit_nop(action_id: @action_id)
      end
    in .readable_fd?
      @io_uring.submit_poll_add(@fd, Crystal::System::Syscall::POLLIN, action_id: @action_id, timeout: timeout)
    in .writable_fd?
      @io_uring.submit_poll_add(@fd, Crystal::System::Syscall::POLLOUT, action_id: @action_id, timeout: timeout)
    end
  end
end
