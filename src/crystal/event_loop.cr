require "./event"

class Thread
  @eb : Crystal::Event::Base?
  @dns_base : Crystal::Event::DnsBase?
  @loop_fiber : Fiber?

  # :nodoc:
  def eb : Crystal::Event::Base
    @eb ||= Crystal::Event::Base.new
  end

  # :nodoc:
  def dns_base : Crystal::Event::DnsBase
    @dns_base ||= self.eb.new_dns_base
  end

  # :nodoc:
  def loop_fiber : Fiber
    @loop_fiber ||= Fiber.new(name: "Event Loop") do
      loop do
        self.eb.run_once
        Crystal::Scheduler.reschedule
      end
    end
  end
end

module Crystal::EventLoop
  def self.after_fork
    raise "Not Supported"
  end

  def self.resume
    loop_fiber.resume
  end

  private def self.eb
    Thread.current.eb
  end

  private def self.dns_base
    Thread.current.dns_base
  end

  private def self.loop_fiber
    Thread.current.loop_fiber
  end

  def self.create_resume_event(fiber)
    eb.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      Crystal::Scheduler.enqueue data.as(Fiber)
    end
  end

  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    eb.new_event(io.fd, flags, io) do |s, flags, data|
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

    eb.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Read)
        io_ref.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_read(timed_out: true)
      end
    end
  end

  def self.create_dns_request(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
    dns_base.getaddrinfo(nodename, servname, hints, data, &callback)
  end
end
