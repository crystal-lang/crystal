{% skip_file if flag?(:win32) %}

module IO::Evented
  @read_timed_out = false
  @write_timed_out = false

  @read_timeout : Time::Span?
  @write_timeout : Time::Span?

  @readers : Deque(Fiber)?
  @writers : Deque(Fiber)?

  @read_event : Crystal::Event?
  @write_event : Crystal::Event?

  # Returns the time to wait when reading before raising an `IO::Timeout`.
  def read_timeout : Time::Span?
    @read_timeout
  end

  # Sets the time to wait when reading before raising an `IO::Timeout`.
  def read_timeout=(timeout : Time::Span?) : ::Time::Span?
    @read_timeout = timeout
  end

  # Sets the number of seconds to wait when reading before raising an `IO::Timeout`.
  def read_timeout=(read_timeout : Number) : Number
    self.read_timeout = read_timeout.seconds
    read_timeout
  end

  # Returns the time to wait when writing before raising an `IO::Timeout`.
  def write_timeout : Time::Span?
    @write_timeout
  end

  # Sets the time to wait when writing before raising an `IO::Timeout`.
  def write_timeout=(timeout : Time::Span?) : ::Time::Span?
    @write_timeout = timeout
  end

  # Sets the number of seconds to wait when writing before raising an `IO::Timeout`.
  def write_timeout=(write_timeout : Number) : Number
    self.write_timeout = write_timeout.seconds
    write_timeout
  end

  def evented_read(slice : Bytes, errno_msg : String) : Int32
    loop do
      bytes_read = yield slice
      if bytes_read != -1
        # `to_i32` is acceptable because `Slice#size` is an Int32
        return bytes_read.to_i32
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new(errno_msg)
      end
    end
  ensure
    resume_pending_readers
  end

  def evented_write(slice : Bytes, errno_msg : String) : Nil
    return if slice.empty?

    begin
      loop do
        bytes_written = yield slice
        if bytes_written != -1
          slice += bytes_written
          return if slice.size == 0
        else
          if Errno.value == Errno::EAGAIN
            wait_writable
          else
            raise Errno.new(errno_msg)
          end
        end
      end
    ensure
      resume_pending_writers
    end
  end

  def evented_send(slice : Bytes, errno_msg : String) : Int32
    bytes_written = yield slice
    raise Errno.new(errno_msg) if bytes_written == -1
    # `to_i32` is acceptable because `Slice#size` is an Int32
    bytes_written.to_i32
  ensure
    resume_pending_writers
  end

  # :nodoc:
  def resume_read(timed_out = false)
    @read_timed_out = timed_out

    if reader = @readers.try &.shift?
      reader.resume
    end
  end

  # :nodoc:
  def resume_write(timed_out = false)
    @write_timed_out = timed_out

    if writer = @writers.try &.shift?
      writer.resume
    end
  end

  protected def wait_readable(timeout = @read_timeout)
    wait_readable(timeout: timeout) { |err| raise err }
  end

  protected def wait_readable(timeout = @read_timeout) : Nil
    readers = (@readers ||= Deque(Fiber).new)
    readers << Fiber.current
    add_read_event(timeout)
    Crystal::Scheduler.reschedule

    if @read_timed_out
      @read_timed_out = false
      yield Timeout.new("Read timed out")
    end
  end

  private def add_read_event(timeout = @read_timeout) : Nil
    event = @read_event ||= Crystal::EventLoop.create_fd_read_event(self)
    event.add timeout
  end

  protected def wait_writable(timeout = @write_timeout)
    wait_writable(timeout: timeout) { |err| raise err }
  end

  protected def wait_writable(timeout = @write_timeout) : Nil
    writers = (@writers ||= Deque(Fiber).new)
    writers << Fiber.current
    add_write_event(timeout)
    Crystal::Scheduler.reschedule

    if @write_timed_out
      @write_timed_out = false
      yield Timeout.new("Write timed out")
    end
  end

  private def add_write_event(timeout = @write_timeout) : Nil
    event = @write_event ||= Crystal::EventLoop.create_fd_write_event(self)
    event.add timeout
  end

  def evented_reopen
    evented_close
  end

  def evented_close
    @read_event.try &.free
    @read_event = nil

    @write_event.try &.free
    @write_event = nil

    if readers = @readers
      Crystal::Scheduler.enqueue readers
      readers.clear
    end

    if writers = @writers
      Crystal::Scheduler.enqueue writers
      writers.clear
    end
  end

  private def resume_pending_readers
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  private def resume_pending_writers
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end
end
