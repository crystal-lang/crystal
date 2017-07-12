require "c/fcntl"

class Crystal::System::FileHandle
  @fd : Int32

  @read_event : Event::Event?
  @write_event : Event::Event?

  @read_timeout : LibC::Timeval?
  @read_timed_out = false
  @write_timeout : LibC::Timeval?
  @write_timed_out = false

  # TODO: make these properties private once sockets no longer use file handles
  getter(readers) { Deque(Fiber).new }
  getter(writers) { Deque(Fiber).new }

  @closed = false

  def initialize(platform_specific : Int32)
    @fd = platform_specific
  end

  def platform_specific : Int32
    @fd
  end

  def read(slice : Bytes) : Int32
    count = slice.size
    loop do
      bytes_read = LibC.read(@fd, slice.pointer(count).as(Void*), count)
      if bytes_read != -1
        # `slice.size` is an Int32 so this is safe.
        return bytes_read.to_i32
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new "Error reading file"
      end
    end
  ensure
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  def write(slice : Bytes) : Nil
    count = slice.size
    loop do
      bytes_written = LibC.write(@fd, slice.pointer(count).as(Void*), count)
      if bytes_written != -1
        count -= bytes_written
        return if count == 0
        slice += bytes_written
      else
        if Errno.value == Errno::EAGAIN
          wait_writable
          next
        elsif Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        else
          raise Errno.new "Error writing file"
        end
      end
    end
  ensure
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  def resume_read(timed_out : Bool = false) : Nil
    @read_timed_out = timed_out

    if reader = @readers.try &.shift?
      reader.resume
    end
  end

  def resume_write(timed_out : Bool = false) : Nil
    @write_timed_out = timed_out

    if writer = @writers.try &.shift?
      writer.resume
    end
  end

  def closed? : Bool
    @closed
  end

  def close : Nil
    return if @closed

    err = nil
    if LibC.close(@fd) != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        err = Errno.new("Error closing file")
      end
    end

    @closed = true

    @read_event.try &.free
    @read_event = nil

    @write_event.try &.free
    @write_event = nil

    if readers = @readers
      Scheduler.enqueue readers
      readers.clear
    end

    if writers = @writers
      Scheduler.enqueue writers
      writers.clear
    end

    raise err if err
  end

  def blocking? : Bool
    (fcntl(LibC::F_GETFL) & LibC::O_NONBLOCK) == 0
  end

  def blocking=(value : Bool) : Bool
    flags = fcntl(LibC::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, flags)

    value
  end

  def close_on_exec? : Bool
    (fcntl(LibC::F_GETFD) & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  def close_on_exec=(value : Bool) : Bool
    flags = fcntl(LibC::F_GETFD)
    if value
      flags |= LibC::FD_CLOEXEC
    else
      flags &= ~LibC::FD_CLOEXEC
    end
    fcntl(LibC::F_SETFD, flags)

    value
  end

  def read_timeout : ::Time::Span?
    to_timespan(@read_timeout)
  end

  def read_timeout=(timeout : ::Time::Span?) : ::Time::Span?
    if timeout
      @read_timeout = to_timeval(timeout)
    else
      @read_timeout = nil
    end

    timeout
  end

  def write_timeout : ::Time::Span?
    to_timespan(@write_timeout)
  end

  def write_timeout=(timeout : ::Time::Span?) : ::Time::Span?
    if timeout
      @write_timeout = to_timeval(timeout)
    else
      @write_timeout = nil
    end

    timeout
  end

  def seek(offset : Number, whence : IO::Seek = IO::Seek::Set) : Int64
    check_open

    seek_value = LibC.lseek(@fd, offset.to_i64, whence)

    if seek_value == -1
      raise Errno.new "Unable to seek"
    end

    seek_value.to_i64
  end

  def tty? : Bool
    LibC.isatty(@fd) == 1
  end

  def reopen(other : FileHandle) : FileHandle
    {% if LibC.methods.includes? "dup3".id %}
      # dup doesn't copy the CLOEXEC flag, so copy it manually using dup3
      flags = other.close_on_exec? ? LibC::O_CLOEXEC : 0
      if LibC.dup3(other.platform_specific, self.platform_specific, flags) == -1
        raise Errno.new("Could not reopen file descriptor")
      end
    {% else %}
      # dup doesn't copy the CLOEXEC flag, copy it manually to the new
      if LibC.dup2(other.platform_specific, self.platform_specific) == -1
        raise Errno.new("Could not reopen file descriptor")
      end

      if other.close_on_exec?
        self.close_on_exec = true
      end
    {% end %}

    # We are now pointing to a new file descriptor, we need to re-register
    # events with libevent and enqueue readers and writers again.
    @read_event.try &.free
    @read_event = nil

    @write_event.try &.free
    @write_event = nil

    if readers = @readers
      Scheduler.enqueue readers
      readers.clear
    end

    if writers = @writers
      Scheduler.enqueue writers
      writers.clear
    end

    other
  end

  def stat : File::Stat
    if LibC.fstat(@fd, out stat) != 0
      raise Errno.new("Unable to get stat")
    end
    File::Stat.new(stat)
  end

  private def fcntl(cmd, arg = 0)
    LibC.fcntl(@fd, cmd, arg).tap do |ret|
      raise Errno.new("fcntl() failed") if ret == -1
    end
  end

  # TODO: make this method private once sockets no longer use file handles
  def wait_readable(timeout = @read_timeout)
    wait_readable(timeout: timeout) { |err| raise err }
  end

  # TODO: make this method private once sockets no longer use file handles
  def wait_readable(timeout = @read_timeout)
    readers << Fiber.current
    add_read_event(timeout: timeout)
    Scheduler.reschedule

    if @read_timed_out
      @read_timed_out = false
      yield Timeout.new("Read timed out")
    end

    nil
  end

  # TODO: make this method private once sockets no longer use file handles
  def add_read_event(timeout = @read_timeout)
    event = @read_event ||= Scheduler.create_fd_read_event(self)
    event.add(timeout)
    nil
  end

  # TODO: make this method private once sockets no longer use file handles
  def wait_writable(timeout = @write_timeout)
    wait_writable(timeout: timeout) { |err| raise err }
  end

  # TODO: make this method private once sockets no longer use file handles
  def wait_writable(timeout = @write_timeout)
    writers << Fiber.current
    add_write_event(timeout: timeout)
    Scheduler.reschedule

    if @write_timed_out
      @write_timed_out = false
      yield Timeout.new("Write timed out")
    end

    nil
  end

  # TODO: make this method private once sockets no longer use file handles
  def add_write_event(timeout = @write_timeout)
    event = @write_event ||= Scheduler.create_fd_write_event(self)
    event.add(timeout)
    nil
  end

  private def to_timespan(timeval : LibC::Timeval?) : ::Time::Span
    return nil unless timeval

    ticks = timeval.tv_sec * ::Time::Span::TicksPerSecond
    ticks += timeval.tv_usec * ::Time::Span::TicksPerMicrosecond
    ::Time::Span.new(ticks)
  end

  private def to_timeval(time : ::Time::Span)
    seconds, remainder_ticks = time.ticks.divmod(::Time::Span::TicksPerSecond)
    LibC::Timeval.new(tv_sec: seconds, tv_usec: remainder_ticks / ::Time::Span::TicksPerMicrosecond)
  end
end
