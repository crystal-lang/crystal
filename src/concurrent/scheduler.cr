require "event"

# :nodoc:
class Scheduler
  @@runnables = Deque(Fiber).new
  @@eb = Event::Base.new

  def self.reschedule
    if runnable = @@runnables.shift?
      runnable.resume
    else
      loop_fiber.resume
    end
    nil
  end

  def self.loop_fiber
    @@loop_fiber ||= Fiber.new { @@eb.run_loop }
  end

  def self.after_fork
    @@eb.reinit
  end

  def self.create_resume_event(fiber)
    @@eb.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      data.as(Fiber).resume
    end
  end

  def self.create_fd_write_event(io : IO::FileDescriptor, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered
    event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data.as(IO::FileDescriptor)
      if flags.includes?(LibEvent2::EventFlags::Write)
        fd_io.resume_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        fd_io.resume_write(timed_out: true)
      end
    end
    event
  end

  def self.create_fd_write_event(sock : Socket, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered
    event = @@eb.new_event(sock.fd, flags, sock) do |s, flags, data|
      sock_ref = data.as(Socket)
      if flags.includes?(LibEvent2::EventFlags::Write)
        sock_ref.resume_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        sock_ref.resume_write(timed_out: true)
      end
    end
    event
  end

  def self.create_fd_read_event(io : IO::FileDescriptor, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered
    event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data.as(IO::FileDescriptor)
      if flags.includes?(LibEvent2::EventFlags::Read)
        fd_io.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        fd_io.resume_read(timed_out: true)
      end
    end
    event
  end

  def self.create_fd_read_event(sock : Socket, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered
    event = @@eb.new_event(sock.fd, flags, sock) do |s, flags, data|
      sock_ref = data.as(Socket)
      if flags.includes?(LibEvent2::EventFlags::Read)
        sock_ref.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        sock_ref.resume_read(timed_out: true)
      end
    end
    event
  end

  def self.create_signal_event(signal : Signal, chan)
    flags = LibEvent2::EventFlags::Signal | LibEvent2::EventFlags::Persist
    event = @@eb.new_event(Int32.new(signal.to_i), flags, chan) do |s, flags, data|
      ch = data.as(Channel::Buffered(Signal))
      sig = Signal.new(s)
      ch.send sig
    end
    event.add
    event
  end

  @@dns_base : Event::DnsBase?

  private def self.dns_base
    @@dns_base ||= @@eb.new_dns_base
  end

  def self.create_dns_request(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
    dns_base.getaddrinfo(nodename, servname, hints, data, &callback)
  end

  def self.enqueue(fiber : Fiber)
    @@runnables << fiber
  end

  def self.enqueue(fibers : Enumerable(Fiber))
    @@runnables.concat fibers
  end
end
