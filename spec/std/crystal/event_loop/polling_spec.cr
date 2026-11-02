{% skip_file unless Crystal::EventLoop.has_constant?(:Polling) %}

require "spec"
require "socket"

describe Crystal::EventLoop::Polling do
  it "doesn't wait on a socket closed in parallel" do
    event_loop = Crystal::EventLoop.current
    pending! "Requires the polling event loop" unless event_loop.is_a?(Crystal::EventLoop::Polling)

    left, right = UNIXSocket.pair
    left.read_timeout = 1.second

    begin
      # another fiber starts closing the socket (see `Socket#unbuffered_close`)
      # before the fd got registered with the event loop: there is nothing to
      # resume yet
      pointerof(left.@closed).value = true
      event_loop.shutdown(left)

      # then the fiber that is about to wait on the socket registers the fd: it
      # must not wait (nothing would resume it) nor register the fd, which would
      # outlive it and be found by the next socket with the same fd
      event_loop.wait_readable(left)
    ensure
      pointerof(left.@closed).value = false
      left.close
      right.close
    end
  end
end
