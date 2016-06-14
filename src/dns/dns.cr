require "thread"
require "./addrinfo"

module DNS
  alias Service = String|Int32|Nil
  # :nodoc:
  alias Response = Pointer(LibC::Addrinfo)|Int32

  @@queue = Thread::Queue(Tuple(String, Service, LibC::Addrinfo, Deque(Response))).new
  @@started_workers = false
  @@threadpool_size = 1

  def self.threadpool_size=(size : Int32)
    raise ArgumentError.new("Can't set threadpool size: threads have already been started") if @@started_workers
    @@threadpool_size = size
  end

  def self.threadpool_size
    @@threadpool_size
  end

  private def self.start_workers
    return if @@started_workers
    @@started_workers = true

    threadpool_size.times do
      Thread.new do
        loop do
          hostname, service, hints, queue = @@queue.pop

          case service
          when Int32
            servname = service.to_s.to_unsafe
            hints.ai_flags |= LibC::AI_NUMERICSERV
          when String
            servname = service.to_unsafe
          else
            servname = Pointer(LibC::Char).null
          end

          code = LibC.getaddrinfo(hostname, servname, pointerof(hints), out addrinfo)
          if code < 0
            queue.push(code)
          else
            queue.push(addrinfo)
          end
        end
      end
    end
  end

  private def self.blocking_getaddrinfo(hostname, service, hints)
    case service
    when Int32
      servname = service.to_s.to_unsafe
      hints.ai_flags |= LibC::AI_NUMERICSERV
    when String
      servname = service.to_unsafe
    else
      servname = Pointer(LibC::Char).null
    end

    code = LibC.getaddrinfo(hostname, servname, pointerof(hints), out addrinfo)
    raise Addrinfo::Error.new(code) if code < 0

    begin
      ai = addrinfo
      until ai.null?
        yield Addrinfo.new(ai.value)
        ai = ai.value.ai_next
      end
    ensure
      LibC.freeaddrinfo(addrinfo)
    end
  end

  def self.getaddrinfo(hostname : String,
                       service : Service = nil,
                       family : Socket::Family = Socket::Family::UNSPEC,
                       type : Socket::Type? = nil,
                       protocol : Socket::Protocol = Socket::Protocol::IP,
                       flags : Addrinfo::Flags = Addrinfo::Flags::None,
                       blocking = false)
    hints = LibC::Addrinfo.new
    hints.ai_flags = flags
    hints.ai_family = family
    hints.ai_socktype = type if type
    hints.ai_protocol = protocol

    if threadpool_size == 0 || blocking
      blocking_getaddrinfo(hostname, service, hints) { |addrinfo| yield addrinfo }
      return
    end
    start_workers unless @@started_workers

    queue = Deque(Response).new(1)
    @@queue.push({hostname, service, hints, queue})

    loop do
      case response = queue.first?
      when Pointer(LibC::Addrinfo)
        begin
          ai = response
          until ai.null?
            yield Addrinfo.new(ai.value)
            ai = ai.value.ai_next
          end
        ensure
          LibC.freeaddrinfo(response)
        end
        return
      when Int32
        raise Addrinfo::Error.new(response)
      else
        Fiber.yield
      end
    end
  end
end
