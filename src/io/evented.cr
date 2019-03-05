{% skip_file if flag?(:win32) %}
require "crystal/wait_deque"

module IO::Evented
  @read_timed_out = false
  @write_timed_out = false

  @read_timeout : Time::Span?
  @write_timeout : Time::Span?

  @pending_fibers = Crystal::WaitDeque.new

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
    end
  end

  def evented_send(slice : Bytes, errno_msg : String) : Int32
    bytes_written = yield slice
    raise Errno.new(errno_msg) if bytes_written == -1
    # `to_i32` is acceptable because `Slice#size` is an Int32
    bytes_written.to_i32
  end

  protected def wait_readable(timeout = @read_timeout)
    wait_readable(timeout: timeout) { |err| raise err }
  end

  protected def wait_readable(timeout = @read_timeout) : Nil
    fiber = Fiber.current
    @pending_fibers << fiber

    begin
      Crystal::EventLoop.wait(self, :read, timeout) do
        yield IO::Timeout.new("Read timed out")
      end
    ensure
      @pending_fibers.delete fiber
    end
  end

  protected def wait_writable(timeout = @write_timeout)
    wait_writable(timeout: timeout) { |err| raise err }
  end

  protected def wait_writable(timeout = @write_timeout) : Nil
    fiber = Fiber.current
    @pending_fibers << fiber

    begin
      Crystal::EventLoop.wait(self, :write, timeout) do
        yield IO::Timeout.new("Write timed out")
      end
    ensure
      @pending_fibers.delete fiber
    end
  end

  def evented_reopen
    evented_close
  end

  def evented_close
    Thread.log "IO#evented_closed"
    pending = @pending_fibers.clear

    pending.unsafe_each do |fiber|
      # FIXME: why is a running fiber still in the list of pending fibers ?!
      next if fiber.running?

      {% if flag?(:mt) %}
        # only enqueue the fiber if we can cancel the event, otherwise the event
        # callback may have been executed in parallel and the fiber be enqueued
        # already:
        Crystal::Scheduler.enqueue(fiber) if fiber.event.cancel
      {% else %}
        Crystal::Scheduler.enqueue(fiber)
      {% end %}
    end
  end
end
