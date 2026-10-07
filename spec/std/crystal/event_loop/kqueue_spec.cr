{% skip_file unless flag?(:freebsd) && Crystal::EventLoop.has_constant?(:Kqueue) %}

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

  it "transfers a pipe whose write filter was not registered" do
    reader, writer = IO.pipe
    writer.close
    first = Crystal::EventLoop::Kqueue.new(1)
    second = Crystal::EventLoop::Kqueue.new(1)
    descriptor = Crystal::EventLoop::Polling::PollDescriptor.new
    index = Crystal::EventLoop::Polling::Arena::Index.new(reader.fd, 0)

    descriptor.take_ownership(first, reader.fd, index)
    descriptor.take_ownership(second, reader.fd, index)
    descriptor.@event_loop.should be(second)

    events = uninitialized LibC::Kevent[2]
    first.@kqueue.wait(events.to_slice, Time::Span.zero).should be_empty
  ensure
    first.try { |event_loop| event_loop.@kqueue.close }
    second.try { |event_loop| event_loop.@kqueue.close }
    reader.try &.close
    writer.try &.close
  end
end
