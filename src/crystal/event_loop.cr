require "thread"
require "./event"

# :nodoc:
module Crystal::EventLoop
  @@eb = uninitialized Crystal::Event::Base
  @@mutex = uninitialized Thread::Mutex
  @@dns_base : Crystal::Event::DnsBase?

  def self.init
    @@eb = Crystal::Event::Base.new
    @@mutex = Thread::Mutex.new
  end

  def self.after_fork
    @@eb.reinit
  end

  def self.run
    @@mutex.synchronize do
      @@eb.loop(:none)
    end
  end

  def self.run_nonblock
    if @@mutex.try_lock
      begin
        @@eb.loop(:non_block)
      ensure
        @@mutex.unlock
      end
    end
  end

  def self.create_resume_event(fiber)
    @@eb.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      Crystal::Scheduler.enqueue(data.as(Fiber))
    end
  end

  def self.create_fd_write_event(io : IO::FileDescriptor, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data.as(IO::FileDescriptor)
      if flags.includes?(LibEvent2::EventFlags::Write)
        fd_io.enqueue_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        fd_io.enqueue_write(timed_out: true)
      end
    end
  end

  def self.create_fd_write_event(sock : Socket, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    @@eb.new_event(sock.fd, flags, sock) do |s, flags, data|
      sock_ref = data.as(Socket)
      if flags.includes?(LibEvent2::EventFlags::Write)
        sock_ref.enqueue_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        sock_ref.enqueue_write(timed_out: true)
      end
    end
  end

  def self.create_fd_read_event(io : IO::FileDescriptor, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data.as(IO::FileDescriptor)
      if flags.includes?(LibEvent2::EventFlags::Read)
        fd_io.enqueue_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        fd_io.enqueue_read(timed_out: true)
      end
    end
  end

  def self.create_fd_read_event(sock : Socket, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    @@eb.new_event(sock.fd, flags, sock) do |s, flags, data|
      sock_ref = data.as(Socket)
      if flags.includes?(LibEvent2::EventFlags::Read)
        sock_ref.enqueue_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        sock_ref.enqueue_read(timed_out: true)
      end
    end
  end

  private def self.dns_base
    @@dns_base ||= @@eb.new_dns_base
  end

  def self.create_dns_request(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
    dns_base.getaddrinfo(nodename, servname, hints, data, &callback)
  end
end
