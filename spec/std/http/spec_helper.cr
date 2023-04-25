require "spec"
require "../spec_helper"
require "../../support/fibers"

private def wait_for(&)
  timeout = {% if flag?(:interpreted) %}
              # TODO: it's not clear why some interpreter specs
              # take more than 5 seconds to bind to a server.
              # See #12429.
              25.seconds
            {% else %}
              5.seconds
            {% end %}
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
def run_server(server, &)
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

# Helper method which runs a *handler*
# Similar to `run_server` but doesn't go through the network stack.
def run_handler(handler, &)
  done = Channel(Exception?).new

  IO::Stapled.pipe do |server_io, client_io|
    processor = HTTP::Server::RequestProcessor.new(handler)
    f = spawn do
      processor.process(server_io, server_io)
    rescue exc
      done.send exc
    else
      done.send nil
    end

    client = HTTP::Client.new(client_io)

    begin
      wait_until_blocked f

      yield client
    ensure
      processor.close
      server_io.close
      if exc = done.receive
        raise exc
      end
    end
  end
end
