{% skip_file unless (flag?(:freebsd) || flag?(:netbsd)) && Crystal::EventLoop.has_constant?(:Kqueue) %}

require "spec"

describe Crystal::EventLoop::Kqueue do
  it "registers a pipe after its peer has written and closed" do
    reader, writer = IO.pipe
    reader.read_timeout = 1.second
    writer.write(Bytes[1, 2, 3])
    writer.flush
    writer.close

    Crystal::EventLoop.current.wait_readable(reader)
    buffer = Bytes.new(3)
    reader.read_fully(buffer)
    buffer.should eq(Bytes[1, 2, 3])
    reader.read_byte.should be_nil
  ensure
    reader.try &.close
    writer.try &.close
  end

  it "does not wait again after a pipe reaches EOF before registration" do
    reader, writer = IO.pipe
    reader.read_timeout = 1.second
    writer.close

    2.times do
      Crystal::EventLoop.current.wait_readable(reader)
      reader.read_byte.should be_nil
    end
  ensure
    reader.try &.close
    writer.try &.close
  end

  it "reports a broken pipe after its reader closes before registration" do
    reader, writer = IO.pipe
    writer.write_timeout = 1.second
    writer.sync = true
    reader.close

    2.times { Crystal::EventLoop.current.wait_writable(writer) }
    error = expect_raises(IO::Error) { writer.write_byte(1) }
    error.os_error.should eq(Errno::EPIPE)
  ensure
    reader.try &.close
    writer.try &.close
  end

  it "transfers a pipe after its peer closes" do
    reader, writer = IO.pipe
    writer.close
    first = Crystal::EventLoop::Kqueue.new(1)
    second = Crystal::EventLoop::Kqueue.new(1)
    descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
    index = Crystal::EventLoop::Polling::Arena::Index.new(reader.fd, 1)

    descriptor.take_ownership(first, reader.fd, index)
    descriptor.take_ownership(second, reader.fd, index)
    descriptor.@event_loop.should be(second)

    events = uninitialized LibC::Kevent[2]
    first.@kqueue.wait(events.to_slice, Time::Span.zero).should be_empty
    ready = second.@kqueue.wait(events.to_slice, Time::Span.zero)
    read_event = ready.find { |event| event.filter == LibC::EVFILT_READ }.not_nil!
    {% if flag?(:bits64) %}
      read_event.udata.address.should eq(index.to_u64)
    {% else %}
      read_event.udata.address.should eq(index.generation)
    {% end %}
  ensure
    first.try { |event_loop| event_loop.@kqueue.close }
    second.try { |event_loop| event_loop.@kqueue.close }
    reader.try &.close
    writer.try &.close
  end

  it "waits for a pipe whose peer is still open" do
    reader, writer = IO.pipe
    event_loop = Crystal::EventLoop::Kqueue.new(1)
    descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
    index = Crystal::EventLoop::Polling::Arena::Index.new(reader.fd, 0)

    descriptor.take_ownership(event_loop, reader.fd, index)
    event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
    descriptor.@readers.add(pointerof(event)).should be_true
  ensure
    event_loop.try { |loop| loop.@kqueue.close }
    reader.try &.close
    writer.try &.close
  end

  it "rejects an invalid descriptor" do
    event_loop = Crystal::EventLoop::Kqueue.new(1)
    descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
    fd = Int32::MAX
    index = Crystal::EventLoop::Polling::Arena::Index.new(fd, 0)

    error = expect_raises(RuntimeError) { descriptor.take_ownership(event_loop, fd, index) }
    error.os_error.should eq(Errno::EBADF)
  ensure
    event_loop.try { |loop| loop.@kqueue.close }
  end

  it "rejects an invalid kqueue for a closed pipe" do
    reader, writer = IO.pipe
    writer.close
    event_loop = Crystal::EventLoop::Kqueue.new(1)
    event_loop.@kqueue.close
    descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
    index = Crystal::EventLoop::Polling::Arena::Index.new(reader.fd, 0)

    error = expect_raises(RuntimeError) { descriptor.take_ownership(event_loop, reader.fd, index) }
    error.os_error.should eq(Errno::EBADF)
  ensure
    reader.try &.close
    writer.try &.close
  end

  {% if flag?(:netbsd) %}
    it "does not mark a named FIFO permanently ready after a writer closes" do
      path = File.tempname("kqueue", ".fifo")
      LibC.mkfifo(path, 0o600).should eq(0)
      read_fd = LibC.open(path, LibC::O_RDONLY | LibC::O_NONBLOCK)
      read_fd.should be >= 0
      reader = IO::FileDescriptor.new(read_fd)
      reader.read_timeout = 1.second
      write_fd = LibC.open(path, LibC::O_WRONLY | LibC::O_NONBLOCK)
      write_fd.should be >= 0
      LibC.close(write_fd).should eq(0)

      event_loop = Crystal::EventLoop::Kqueue.new(1)
      descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
      index = Crystal::EventLoop::Polling::Arena::Index.new(read_fd, 0)
      descriptor.take_ownership(event_loop, read_fd, index)
      descriptor.@readers.@always_ready.should be_false

      write_fd = LibC.open(path, LibC::O_WRONLY | LibC::O_NONBLOCK)
      write_fd.should be >= 0
      writer = IO::FileDescriptor.new(write_fd)
      writer.write_byte(1)
      writer.flush
      reader.read_byte.should eq(1_u8)
    ensure
      event_loop.try { |loop| loop.@kqueue.close }
      reader.try &.close
      writer.try &.close
      File.delete(path) if path && File.exists?(path)
    end

    it "preserves errors for a non-pipe descriptor with FIFO type" do
      target = Crystal::System::Kqueue.new
      fd = target.@kq
      event_loop = Crystal::EventLoop::Kqueue.new(1)
      descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
      index = Crystal::EventLoop::Polling::Arena::Index.new(fd, 0)

      error = expect_raises(RuntimeError) { descriptor.take_ownership(event_loop, fd, index) }
      error.os_error.should eq(Errno::EINVAL)
    ensure
      event_loop.try { |loop| loop.@kqueue.close }
      target.try &.close
    end
  {% end %}
end
