require "mutex"
require "thread/queue"
require "./resolver"

class Socket
  struct Addrinfo
    # Threaded DNS resolver.
    #
    # Calls the system `getaddrinfo` function in a thread pool, blocking only
    # the current `Fiber`, not the event loop (unlike the `Blocking` resolver).
    #
    # The threaded resolver only starts a single thread. You'll may want to
    # start many, depending on your need for concurrential resolves.
    #
    # A `timeout` (in seconds) may be specified; an `IO::Timeout` exception will
    # be raised if the system can't resolve the domain until the timeout is
    # reached. The resolver thread will still be blocked until `getaddrinfo`
    # returns thought, and not available to resolve more domains in the
    # meantime.
    #
    # Example:
    # ```
    # Socket::Addrinfo.resolver = Socket::Addrinfo::Threaded.new(size: 5)
    # ```
    class Threaded < Resolver
      # :nodoc:
      alias Request = Tuple(String, Service, Socket::Family, Socket::Type, Socket::Protocol, Deque(Response))

      # :nodoc:
      alias Response = Pointer(LibC::Addrinfo) | Int32

      def initialize(@size = 1, @timeout : Int32? = nil)
        @started = false
        @requests = Thread::Queue(Request).new
        @mutex = Mutex.new
      end

      def getaddrinfo(domain, service, family, type, protocol, timeout = @timeout, &block)
        @mutex.synchronize { start_workers }
        start = Time.now

        queue = Deque(Response).new(1)
        @requests.push({domain, service, family, type, protocol, queue})

        loop do
          case response = queue.first?
          when Pointer(LibC::Addrinfo)
            begin
              yield Addrinfo.new(response)
            rescue
              LibC.freeaddrinfo(response)
            end
          when Int32
            if response == LibC::EAI_NONAME
              raise Socket::Error.new("No address found for #{domain}:#{service} over #{protocol}")
            end
            raise Socket::Error.new("getaddrinfo: #{String.new(LibC.gai_strerror(response))}")
          else
            if timeout && ((Time.now - start.not_nil!) > timeout.seconds)
              raise IO::Timeout.new("Failed to resolve #{domain} in #{timeout} #seconds")
            end
            Fiber.yield
          end
        end
      end

      private def start_workers
        return if @started
        @started = true

        @size.times do
          Thread.new do
            loop do
              domain, service, family, type, protocol, queue = @requests.pop
              response = resolve(domain, service, family, type, protocol)
              queue.push(response)
            end
          end
        end
      end

      private def resolve(domain, service, family, type, protocol)
        hints = LibC::Addrinfo.new
        hints.ai_family = (family || Family::UNSPEC).to_i32
        hints.ai_socktype = type
        hints.ai_protocol = protocol
        hints.ai_flags = 0

        if service.is_a?(Int)
          hints.ai_flags |= LibC::AI_NUMERICSERV

          {% if flag?(:darwin) %}
            # avoid a segfault on macOS < 10.12
            if service == 0 || service == nil
              service = "00"
            end
          {% end %}
        end

        code = LibC.getaddrinfo(domain, service.to_s, pointerof(hints), out ptr)
        code == 0 ? ptr : code
      end
    end
  end
end
