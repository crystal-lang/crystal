require "./addrinfo"

# :nodoc:
#
# Connection racing as per RFC 8305 ("Happy Eyeballs Version 2"), sections 4
# and 5. DNS resolution and the initial address preference (RFC 6724) remain
# the responsibility of the system resolver.
module Socket::HappyEyeballs
  # Time to wait for a connection attempt to succeed before starting the next
  # one in parallel ("Connection Attempt Delay").
  CONNECTION_ATTEMPT_DELAY = 250.milliseconds

  # Global switch for `TCPSocket.fast_fallback?`. Kept here rather than in
  # `TCPSocket` because class variables aren't shared with subclasses.
  class_property? enabled : Bool = true

  # Interleaves the addresses by address family, starting with the family of
  # the first address, while keeping the relative order within each family
  # (section 4, with a "First Address Family Count" of 1).
  def self.interleave(addrinfos : Indexable(Addrinfo)) : Array(Addrinfo)
    return addrinfos.to_a if addrinfos.size < 2

    first_family = addrinfos.first.family
    preferred, others = addrinfos.partition(&.family.==(first_family))

    result = Array(Addrinfo).new(addrinfos.size)
    Math.max(preferred.size, others.size).times do |i|
      preferred[i]?.try { |addrinfo| result << addrinfo }
      others[i]?.try { |addrinfo| result << addrinfo }
    end
    result
  end

  # Races connection attempts to *addrinfos* (section 5).
  #
  # Yields each address in turn to create a socket, then starts a connection
  # attempt. The next attempt starts as soon as the previous one failed, or
  # after *delay* without any attempt having succeeded. An address is skipped
  # when creating its socket raises.
  #
  # The *connect_timeout* limits the whole race, not each attempt: every
  # attempt times out at the same deadline, and no attempt starts after it.
  #
  # Returns the first connected socket and closes all the other ones. Returns
  # the last error if every attempt failed, or `nil` if there are no addresses.
  # Only returns once every connection attempt has finished.
  #
  # The socket must implement `#connect(addrinfo, timeout, &)` that yields the
  # error (if any) instead of raising, and `#close` that cancels a pending
  # connection attempt.
  def self.connect(addrinfos : Indexable(Addrinfo), connect_timeout : Time::Span? = nil, delay : Time::Span = CONNECTION_ATTEMPT_DELAY, & : Addrinfo -> T) : T | Exception | Nil forall T
    addrinfos = interleave(addrinfos)
    deadline = Time.instant + connect_timeout if connect_timeout

    # buffered so attempts never block when reporting their result, even after
    # we stopped listening
    results = Channel({T, Exception?}).new(addrinfos.size)
    pending = [] of T
    error = nil
    index = 0

    begin
      loop do
        # start the next connection attempt
        while index < addrinfos.size
          if deadline
            attempt_timeout = deadline - Time.instant
            unless attempt_timeout.positive?
              # too late to start another attempt: skip the remaining addresses
              error = IO::TimeoutError.new("Connect timed out")
              index = addrinfos.size
              break
            end
          end

          addrinfo = addrinfos[index]
          index += 1

          begin
            socket = yield addrinfo
          rescue ex
            # e.g. the address family isn't supported: try the next address
            error = ex
            next
          end

          pending << socket
          spawn_attempt(socket, addrinfo, attempt_timeout, results)
          break
        end

        # every attempt failed
        return error if pending.empty?

        socket, result =
          if index < addrinfos.size
            # wait for an attempt to complete, or start another attempt in
            # parallel after the delay
            select
            when r = results.receive
              r
            when timeout(delay)
              next
            end
          else
            results.receive
          end

        pending.delete(socket)

        if result
          # the attempt failed: start the next one immediately
          error = result
          socket.close
        else
          return socket
        end
      end
    ensure
      # cancel the attempts still in progress (or that also succeeded but
      # lost) and wait for their fibers to finish
      pending.each(&.close)
      pending.size.times { results.receive }
    end
  end

  private def self.spawn_attempt(socket, addrinfo, connect_timeout, results) : Nil
    spawn(name: "Socket::HappyEyeballs") do
      error =
        begin
          socket.connect(addrinfo, connect_timeout) { |err| err }
        rescue ex
          ex
        end
      results.send({socket, error})
    end
  end
end
