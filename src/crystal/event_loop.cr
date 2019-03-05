require "./event"

module Crystal::EventLoop
  @@eb = uninitialized Crystal::Event::Base
  @@dns_base : Crystal::Event::DnsBase?

  {% if flag?(:mt) %}
    @@mutex = uninitialized Thread::Mutex
  {% end %}

  # :nodoc:
  def self.event_base
    @@eb
  end

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
    def self.run_once
      @@mutex.synchronize do
        @@eb.loop(:once)
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
  {% else %}
    def self.resume
      loop_fiber.resume
    end

    private def self.loop_fiber
      @@loop_fiber ||= Fiber.new { @@eb.loop }
    end
  {% end %}

  def self.wait(io : IO::Evented, what : LibEvent2::EventFlags, timeout = nil)
    fiber = Fiber.current

    @@eb.event_assign(fiber.event, io.fd, what, fiber) do |_, flags, data|
      f = data.as(Fiber)

      if flags.includes?(:timeout)
        f.event.timed_out = true
      end

      {% if flag?(:mt) %}
        # only enqueue the fiber if we can cancel the event; the event may be
        # canceled in parallel, and the fiber would end up being enqueued twice:
        if f.event.cancel(delete: false)
          Crystal::Scheduler.enqueue(f)
        end
      {% else %}
        f.resume
      {% end %}
    end
    fiber.event.add(timeout)

    Crystal::Scheduler.reschedule

    if fiber.event.timed_out?
      yield
    end
  end

  def self.sleep(time : Time::Span)
    fiber = Fiber.current

    @@eb.event_assign(fiber.event, -1, :none, fiber) do |_, _, data|
      f = data.as(Fiber)

      {% if flag?(:mt) %}
        Crystal::Scheduler.enqueue(f)
      {% else %}
        f.resume
      {% end %}
    end
    fiber.event.add(time)

    Crystal::Scheduler.reschedule
  end

  private def self.dns_base
    @@dns_base ||= @@eb.new_dns_base
  end

  def self.create_dns_request(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
    dns_base.getaddrinfo(nodename, servname, hints, data, &callback)
  end
end
