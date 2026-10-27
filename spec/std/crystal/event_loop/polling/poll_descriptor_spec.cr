{% skip_file unless Crystal::EventLoop.has_constant?(:Polling) %}

require "spec"

class Crystal::EventLoop::FakeLoop < Crystal::EventLoop::Polling
  def self.default_file_blocking?
    false
  end

  def self.default_socket_blocking?
    false
  end

  getter operations = [] of {Symbol, Int32, Arena::Index | Bool}

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
  end

  def interrupt : Nil
  end

  protected def system_add(fd : Int32, index : Arena::Index) : RegisteredEvents
    operations << {:add, fd, index}
    RegisteredEvents::READ
  end

  protected def system_del(fd : Int32, closing = true) : Nil
    operations << {:del, fd, closing}
  end

  protected def system_del(fd : Int32, closing = true, &) : Nil
    operations << {:del, fd, closing}
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
      fd = Int32::MAX
      pd = Crystal::EventLoop::Polling::PollDescriptor.new
      index = Crystal::EventLoop::Polling::Arena::Index.new(fd, 0)
      evloop = Crystal::EventLoop::Polling::FakeLoop.new

      pd.take_ownership(evloop, fd, index)
      pd.@event_loop.should be(evloop)

      evloop.operations.should eq([
        {:add, fd, index},
      ])
    end

    it "moves a poll descriptor to another evloop instance" do
      fd = Int32::MAX
      pd = Crystal::EventLoop::Polling::PollDescriptor.new
      index = Crystal::EventLoop::Polling::Arena::Index.new(fd, 0)

      evloop1 = Crystal::EventLoop::Polling::FakeLoop.new
      evloop2 = Crystal::EventLoop::Polling::FakeLoop.new

      pd.take_ownership(evloop1, fd, index)
      pd.take_ownership(evloop2, fd, index)

      pd.@event_loop.should be(evloop2)

      evloop1.operations.should eq([
        {:add, fd, index},
        {:del, fd, false},
      ])
      evloop2.operations.should eq([
        {:add, fd, index},
      ])
    end

    it "can't move to the current evloop" do
      fd = Int32::MAX
      pd = Crystal::EventLoop::Polling::PollDescriptor.new
      index = Crystal::EventLoop::Polling::Arena::Index.new(fd, 0)

      evloop = Crystal::EventLoop::Polling::FakeLoop.new

      pd.take_ownership(evloop, fd, index)
      expect_raises(Exception) { pd.take_ownership(evloop, fd, index) }
    end

    it "can't move with pending waiters" do
      fd = Int32::MAX
      pd = Crystal::EventLoop::Polling::PollDescriptor.new
      index = Crystal::EventLoop::Polling::Arena::Index.new(fd, 0)
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)

      evloop1 = Crystal::EventLoop::Polling::FakeLoop.new
      pd.take_ownership(evloop1, fd, index)
      pd.@reader.add(pointerof(event))

      evloop2 = Crystal::EventLoop::Polling::FakeLoop.new
      expect_raises(RuntimeError) { pd.take_ownership(evloop2, fd, index) }

      pd.@event_loop.should be(evloop1)

      evloop1.operations.should eq([
        {:add, fd, index},
      ])
      evloop2.operations.should be_empty
    end
  end
end
