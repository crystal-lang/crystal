{% skip_file if flag?(:win32) %}

require "crystal/thread_local_value"

module IO::Evented
  @read_timed_out = false
  @write_timed_out = false

  @read_timeout : Time::Span?
  @write_timeout : Time::Span?

  @readers = Crystal::ThreadLocalValue(Deque(Fiber)).new
  @writers = Crystal::ThreadLocalValue(Deque(Fiber)).new

  @read_event = Crystal::ThreadLocalValue(Crystal::EventLoop::Event).new
  @write_event = Crystal::ThreadLocalValue(Crystal::EventLoop::Event).new

  # Returns the time to wait when reading before raising an `IO::TimeoutError`.
  def read_timeout : Time::Span?
    @read_timeout
  end

  # Sets the time to wait when reading before raising an `IO::TimeoutError`.
  def read_timeout=(timeout : Time::Span?) : ::Time::Span?
    @read_timeout = timeout
  end

  # Sets the number of seconds to wait when reading before raising an `IO::TimeoutError`.
  def read_timeout=(read_timeout : Number) : Number
    self.read_timeout = read_timeout.seconds
    read_timeout
  end

  # Returns the time to wait when writing before raising an `IO::TimeoutError`.
  def write_timeout : Time::Span?
    @write_timeout
  end

  # Sets the time to wait when writing before raising an `IO::TimeoutError`.
  def write_timeout=(timeout : Time::Span?) : ::Time::Span?
    @write_timeout = timeout
  end

  # Sets the number of seconds to wait when writing before raising an `IO::TimeoutError`.
  def write_timeout=(write_timeout : Number) : Number
    self.write_timeout = write_timeout.seconds
    write_timeout
  end

  def evented_read(slice : Bytes, errno_msg : String, &) : Int32
    loop do
      bytes_read = yield slice
      if bytes_read != -1
        # `to_i32` is acceptable because `Slice#size` is an Int32
        return bytes_read.to_i32
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise IO::Error.from_errno(errno_msg)
      end
    end
  ensure
    resume_pending_readers
  end

  def evented_write(slice : Bytes, errno_msg : String, &) : Nil
    return if slice.empty?

    begin
      loop do
        # TODO: Investigate why the .to_i64 is needed as a workaround for #8230
        bytes_written = (yield slice).to_i64
        if bytes_written != -1
          slice += bytes_written
          return if slice.size == 0
        else
          if Errno.value == Errno::EAGAIN
            wait_writable
          else
            raise IO::Error.from_errno(errno_msg)
          end
        end
      end
    ensure
      resume_pending_writers
    end
  end

  def evented_send(slice : Bytes, errno_msg : String, &) : Int32
    bytes_written = yield slice
    raise Socket::Error.from_errno(errno_msg) if bytes_written == -1
    # `to_i32` is acceptable because `Slice#size` is an Int32
    bytes_written.to_i32
  ensure
    resume_pending_writers
  end

  # :nodoc:
  def resume_read(timed_out = false) : Nil
    @read_timed_out = timed_out

    if reader = @readers.get?.try &.shift?
      Crystal::Scheduler.enqueue reader
    end
  end

  # :nodoc:
  def resume_write(timed_out = false) : Nil
    @write_timed_out = timed_out

    if writer = @writers.get?.try &.shift?
      Crystal::Scheduler.enqueue writer
    end
  end

  # :nodoc:
  def wait_readable(timeout = @read_timeout) : Nil
    wait_readable(timeout: timeout) { raise TimeoutError.new("Read timed out") }
  end

  # :nodoc:
  def wait_readable(timeout = @read_timeout, *, raise_if_closed = true, &) : Nil
    readers = @readers.get { Deque(Fiber).new }
    readers << Fiber.current
    add_read_event(timeout)
    Crystal::Scheduler.reschedule

    if @read_timed_out
      @read_timed_out = false
      yield
    end

    check_open if raise_if_closed
  end

  private def add_read_event(timeout = @read_timeout) : Nil
    event = @read_event.get { Crystal::Scheduler.event_loop.create_fd_read_event(self) }
    event.add timeout
  end

  # :nodoc:
  def wait_writable(timeout = @write_timeout) : Nil
    wait_writable(timeout: timeout) { raise TimeoutError.new("Write timed out") }
  end

  # :nodoc:
  def wait_writable(timeout = @write_timeout, &) : Nil
    writers = @writers.get { Deque(Fiber).new }
    writers << Fiber.current
    add_write_event(timeout)
    Crystal::Scheduler.reschedule

    if @write_timed_out
      @write_timed_out = false
      yield
    end

    check_open
  end

  private def add_write_event(timeout = @write_timeout) : Nil
    event = @write_event.get { Crystal::Scheduler.event_loop.create_fd_write_event(self) }
    event.add timeout
  end

  def evented_reopen : Nil
    evented_close
  end

  def evented_close : Nil
    @read_event.consume_each &.free

    @write_event.consume_each &.free

    @readers.consume_each do |readers|
      Crystal::Scheduler.enqueue readers
    end

    @writers.consume_each do |writers|
      Crystal::Scheduler.enqueue writers
    end
  end

  private def resume_pending_readers
    if (readers = @readers.get?) && !readers.empty?
      add_read_event
    end
  end

  private def resume_pending_writers
    if (writers = @writers.get?) && !writers.empty?
      add_write_event
    end
  end
end
