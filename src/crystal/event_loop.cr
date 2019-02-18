require "./event"

module Crystal::EventLoop
  @@eb = uninitialized Crystal::Event::Base
  @@dns_base : Crystal::Event::DnsBase?

  {% if flag?(:mt) %}
    @@mutex = uninitialized Thread::Mutex
  {% end %}

  def self.init
    @@eb = Crystal::Event::Base.new
    {% if flag?(:mt) %}
      @@mutex = Thread::Mutex.new
    {% end %}
  end

  def self.after_fork
    @@eb.reinit
  end

  {% if flag?(:mt) %}
    def self.run
      @@mutex.synchronize { @@eb.loop(:none) }
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
  {% else %}
    def self.resume
      loop_fiber.resume
    end

    private def self.loop_fiber
      @@loop_fiber ||= Fiber.new { @@eb.loop }
    end
  {% end %}

  def self.create_resume_event(fiber)
    @@eb.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      {% if flag?(:mt) %}
        data.as(Fiber).enqueue
      {% else %}
        data.as(Fiber).resume
      {% end %}
    end
  end

  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false)
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    @@eb.new_event(io.fd, flags, io) do |s, flags, data|
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

    @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Read)
        io_ref.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_read(timed_out: true)
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
