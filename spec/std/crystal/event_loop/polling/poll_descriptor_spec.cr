{% skip_file unless Crystal::EventLoop.has_constant?(:Polling) %}

require "spec"

class Crystal::EventLoop::FakeLoop < Crystal::EventLoop::Polling
  def self.default_file_blocking?
    false
  end

  def self.default_socket_blocking?
    false
  end

  getter operations = [] of {Symbol, IO, Nil | Bool}

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
  end

  def interrupt : Nil
  end

  protected def system_add(io) : RegisteredEvents
    operations << {:add, io, nil}
    RegisteredEvents::READ
  end

  protected def system_del(io, closing = true) : Nil
    operations << {:del, io, closing}
  end

  protected def system_del(io, closing = true, &) : Nil
    operations << {:del, io, closing}
  end

  private def system_set_timer(time : Time::Instant?) : Nil
  end
end

describe Crystal::EventLoop::Polling::PollDescriptor do
  it "allows at most one reader and one writer" do
    pd = Crystal::EventLoop::Polling::PollDescriptor.new
    reader = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
    writer = Crystal::EventLoop::Polling::Event.new(:io_write, Fiber.current)

    pd.empty?.should be_true
    pd.@reader.add(pointerof(reader)).should be_true
    pd.@writer.add(pointerof(writer)).should be_true
    pd.empty?.should be_false

    pd.@reader.delete(pointerof(reader))
    pd.empty?.should be_false
    pd.@writer.delete(pointerof(writer))
    pd.empty?.should be_true
  end

  describe "#take_ownership" do
    it "associates a poll descriptor to an evloop instance" do
      io = IO::FileDescriptor.new(Int32::MAX)
      pd = Crystal::EventLoop::Polling::PollDescriptor.new
      evloop = Crystal::EventLoop::Polling::FakeLoop.new

      pd.take_ownership(evloop, io)
      pd.@event_loop.should be(evloop)

      evloop.operations.should eq([
        {:add, io, nil},
      ])
    end

    it "moves a poll descriptor to another evloop instance" do
      io = IO::FileDescriptor.new(Int32::MAX)
      pd = Crystal::EventLoop::Polling::PollDescriptor.new

      evloop1 = Crystal::EventLoop::Polling::FakeLoop.new
      evloop2 = Crystal::EventLoop::Polling::FakeLoop.new

      pd.take_ownership(evloop1, io)
      pd.take_ownership(evloop2, io)

      pd.@event_loop.should be(evloop2)

      evloop1.operations.should eq([
        {:add, io, nil},
        {:del, io, false},
      ])
      evloop2.operations.should eq([
        {:add, io, nil},
      ])
    end

    it "associates a poll descriptor once to the same evloop instance" do
      io = IO::FileDescriptor.new(Int32::MAX)
      pd = Crystal::EventLoop::Polling::PollDescriptor.new

      evloop = Crystal::EventLoop::Polling::FakeLoop.new

      pd.take_ownership(evloop, io)
      pd.take_ownership(evloop, io)

      evloop.operations.should eq([
        {:add, io, nil},
      ])
    end

    it "can't move with pending waiters" do
      io = IO::FileDescriptor.new(Int32::MAX)
      pd = Crystal::EventLoop::Polling::PollDescriptor.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)

      evloop1 = Crystal::EventLoop::Polling::FakeLoop.new
      pd.take_ownership(evloop1, io)
      pd.@reader.add(pointerof(event))

      evloop2 = Crystal::EventLoop::Polling::FakeLoop.new
      expect_raises(RuntimeError) { pd.take_ownership(evloop2, io) }

      pd.@event_loop.should be(evloop1)

      evloop1.operations.should eq([
        {:add, io, nil},
      ])
      evloop2.operations.should be_empty
    end
  end
end
