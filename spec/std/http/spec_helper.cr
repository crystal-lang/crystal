require "spec"
require "../spec_helper"
require "../../support/fibers"

private def wait_for(timeout = 5.seconds)
  now = Time.monotonic

  until yield
    Fiber.yield

    if (Time.monotonic - now) > timeout
      raise "server failed to start within #{timeout}"
    end
  end
end

# Helper method which runs *server*
# 1. Spawns `server.listen` in a new fiber.
# 2. Waits until `server.listening?`.
# 3. Yields to the given block.
# 4. Ensures the server is closed.
# 5. After returning from the block, it waits for the server to gracefully
#    shut down before continuing execution in the current fiber.
# 6. If the listening fiber raises an exception, it is rescued and re-raised
#    in the current fiber.
def run_server(server)
  server_done = Channel(Exception?).new

  f = spawn do
    server.listen
  rescue exc
    server_done.send exc
  else
    server_done.send nil
  end

  begin
    wait_for { server.listening? }
    wait_until_blocked f

    yield server_done
  ensure
    server.close unless server.closed?

    if exc = server_done.receive
      raise exc
    end
  end
end
