module IO::Syscall
  @read_timed_out = false
  @write_timed_out = false

  @read_timeout : Time::Span?
  @write_timeout : Time::Span?

  @readers : Deque(Fiber)?
  @writers : Deque(Fiber)?

  # Returns the time to wait when reading before raising an `IO::Timeout`.
  def read_timeout : Time::Span?
    @read_timeout
  end

  # Sets the time to wait when reading before raising an `IO::Timeout`.
  def read_timeout=(timeout : Time::Span?) : ::Time::Span?
    @read_timeout = timeout
  end

  # Set the number of seconds to wait when reading before raising an `IO::Timeout`.
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

  # Set the number of seconds to wait when writing before raising an `IO::Timeout`.
  def write_timeout=(write_timeout : Number) : Number
    self.write_timeout = write_timeout.seconds
    write_timeout
  end

  def read_syscall_helper(slice : Bytes, errno_msg : String) : Int32
    loop do
      bytes_read = yield
      if bytes_read != -1
        return bytes_read
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new(errno_msg)
      end
    end
  ensure
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  def write_syscall_helper(slice : Bytes, errno_msg : String) : Nil
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
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
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

  private def wait_readable(timeout = @read_timeout)
    wait_readable(timeout: timeout) { |err| raise err }
  end

  private def wait_readable(timeout = @read_timeout)
    readers = (@readers ||= Deque(Fiber).new)
    readers << Fiber.current
    add_read_event(timeout)
    Scheduler.reschedule

    if @read_timed_out
      @read_timed_out = false
      yield Timeout.new("Read timed out")
    end

    nil
  end

  private abstract def add_read_event(timeout = @read_timeout)

  private def wait_writable(timeout = @write_timeout)
    wait_writable(timeout: timeout) { |err| raise err }
  end

  private def wait_writable(timeout = @write_timeout)
    writers = (@writers ||= Deque(Fiber).new)
    writers << Fiber.current
    add_write_event(timeout)
    Scheduler.reschedule

    if @write_timed_out
      @write_timed_out = false
      yield Timeout.new("Write timed out")
    end

    nil
  end

  private abstract def add_write_event(timeout = @write_timeout)

  private def reschedule_waiting
    if readers = @readers
      Scheduler.enqueue readers
      readers.clear
    end

    if writers = @writers
      Scheduler.enqueue writers
      writers.clear
    end
  end
end
