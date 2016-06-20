require "thread"

class Socket
  module Addrinfo
    alias Service = String|Int32|Nil
    # :nodoc:
    alias Response = Pointer(LibC::Addrinfo)|Int32

    @[Flags]
    enum Flags
      PASSIVE     = LibC::AI_PASSIVE
      CANONNAME   = LibC::AI_CANONNAME
      NUMERICHOST = LibC::AI_NUMERICHOST
      NUMERICSERV = LibC::AI_NUMERICSERV
      V4MAPPED    = LibC::AI_V4MAPPED
      ALL         = LibC::AI_ALL
      ADDRCONFIG  = LibC::AI_ADDRCONFIG
    end

    class Error < Exception
      enum Code
        AGAIN    = LibC::EAI_AGAIN
        BADFLAGS = LibC::EAI_BADFLAGS
        FAIL     = LibC::EAI_FAIL
        FAMILY   = LibC::EAI_FAMILY
        MEMORY   = LibC::EAI_MEMORY
        NONAME   = LibC::EAI_NONAME
        SERVICE  = LibC::EAI_SERVICE
        SOCKTYPE = LibC::EAI_SOCKTYPE
        SYSTEM   = LibC::EAI_SYSTEM
        OVERFLOW = LibC::EAI_OVERFLOW
      end

      getter code : Code

      def initialize(@code : Code)
        super String.new(LibC.gai_strerror(code))
      end

      def self.new(code : Int32)
        new Code.new(code)
      end
    end

    @@queue = Thread::Queue(Tuple(String, Service, LibC::Addrinfo, Deque(Response))).new
    @@started_workers = false
    @@threadpool_size = 1

    def self.threadpool_size=(size : Int32)
      raise ArgumentError.new("Can't change threadpool size: threads have already been started") if @@started_workers
      @@threadpool_size = size
    end

    def self.threadpool_size
      @@threadpool_size
    end

    # Yields LibC::Addrinfo to the block while the block returns false and there
    # are no more LibC::Addrinfo results.
    #
    # The block must return true if it succeeded using that address info (eg: to
    # connect or bind), and a falsy value otherwise. If it returns false and the
    # LibC::Addrinfo has a next LibC::Addrinfo, it will be yielded to the block,
    # and so on.
    protected def self.resolve(hostname : String,
                     service : Service = nil,
                     family : Family = Family::UNSPEC,
                     type : Type? = nil,
                     protocol : Protocol = Protocol::IP,
                     flags : Flags = Flags::None,
                     timeout = nil,
                     blocking = false)
      hints = LibC::Addrinfo.new
      hints.ai_flags = flags
      hints.ai_family = family
      hints.ai_socktype = type if type
      hints.ai_protocol = protocol

      if threadpool_size == 0 || blocking
        addrinfo = resolve_blocking(hostname, service, hints)
      else
        addrinfo = resolve_threaded(hostname, service, hints, timeout)
      end

      begin
        ai = addrinfo
        until ai.null?
          return if yield ai.value
          ai = ai.value.ai_next
        end
      ensure
        LibC.freeaddrinfo(addrinfo)
      end
    end

    private def self.resolve_blocking(hostname, service, hints)
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
      raise Error.new(code) if code < 0
      addrinfo
    end

    private def self.resolve_threaded(hostname, service, hints, timeout = nil)
      start_workers unless @@started_workers
      start = Time.now if timeout

      queue = Deque(Response).new(1)
      @@queue.push({hostname, service, hints, queue})

      loop do
        case response = queue.first?
        when Pointer(LibC::Addrinfo)
          return response
        when Int32
          raise Error.new(response)
        else
          if timeout && ((Time.now - start.not_nil!) > timeout.seconds)
            raise IO::Timeout.new("Failed to resolve #{hostname} in #{timeout} seconds")
          else
            Fiber.yield
          end
        end
      end
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
  end
end
