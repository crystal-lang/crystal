require "./event"

class Thread
  # :nodoc:
  getter(event_base) { Crystal::Event::Base.new }
end

module Crystal::EventLoop
  {% unless flag?(:preview_mt) %}
    def self.after_fork
      Thread.current.event_base.reinit
    end
  {% end %}

  def self.run_once
    Thread.current.event_base.run_once
  end

  private def self.event_base
    Thread.current.event_base
  end

  def self.create_resume_event(fiber)
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      Crystal::Scheduler.enqueue data.as(Fiber)
    end
  end

  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    event_base.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Write)
        io_ref.resume_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_write(timed_out: true)
      end
    end
  end

  def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    event_base.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Read)
        io_ref.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_read(timed_out: true)
      end
    end
  end
end
