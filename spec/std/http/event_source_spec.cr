require "./spec_helper"
require "../spec_helper"
require "../../../src/http/event_source"
require "http/server"
require "../../support/fibers"

require "http/cookie"

describe HTTP::EventSource do
  describe HTTP::EventSource::Event do
    it "creates event with defaults" do
      event = HTTP::EventSource::Event.new
      event.type.should be_nil
      event.data.should eq("")
      event.id.should be_nil
      event.retry.should be_nil
    end

    it "creates event with all fields" do
      event = HTTP::EventSource::Event.new(
        type: "status",
        data: "connected",
        id: "123",
        retry: 5000
      )
      event.type.should eq("status")
      event.data.should eq("connected")
      event.id.should eq("123")
      event.retry.should eq(5000)
    end
  end

  describe HTTP::EventSource::Parser do
    it "parses simple message event" do
      io = IO::Memory.new("data: hello\n\n")
      parser = HTTP::EventSource::Parser.new(io)
      events = parser.to_a
      events.size.should eq(1)
      events[0].type.should be_nil
      events[0].data.should eq("hello")
    end

    it "parses named event" do
      io = IO::Memory.new("event: status\ndata: connected\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].type.should eq("status")
      events[0].data.should eq("connected")
    end

    it "handles multi-line data" do
      io = IO::Memory.new("data: line1\ndata: line2\ndata: line3\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].data.should eq("line1\nline2\nline3")
    end

    it "parses event ID" do
      io = IO::Memory.new("id: 123\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].id.should eq("123")
    end

    it "ignores id with null character" do
      io = IO::Memory.new("id: bad\0id\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].id.should be_nil
    end

    it "parses retry interval" do
      io = IO::Memory.new("retry: 5000\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].retry.should eq(5000)
    end

    it "ignores non-numeric retry" do
      io = IO::Memory.new("retry: abc\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].retry.should be_nil
    end

    it "ignores negative retry" do
      io = IO::Memory.new("retry: -100\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].retry.should be_nil
    end

    it "ignores comments" do
      io = IO::Memory.new(": this is a comment\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].data.should eq("test")
    end

    it "handles field with no value" do
      io = IO::Memory.new("data\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].data.should eq("")
    end

    it "strips single leading space from value" do
      io = IO::Memory.new("data:  two spaces\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].data.should eq(" two spaces")
    end

    it "handles no space after colon" do
      io = IO::Memory.new("data:no space\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].data.should eq("no space")
    end

    it "ignores unknown fields" do
      io = IO::Memory.new("unknown: field\ndata: test\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].data.should eq("test")
    end

    it "parses event with all fields" do
      io = IO::Memory.new("event: update\nid: msg-123\nretry: 3000\ndata: payload\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].type.should eq("update")
      events[0].id.should eq("msg-123")
      events[0].retry.should eq(3000)
      events[0].data.should eq("payload")
    end

    it "resets parser state after building event" do
      io = IO::Memory.new("event: first\ndata: first data\n\ndata: second data\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(2)
      events[0].type.should eq("first")
      events[0].data.should eq("first data")
      events[1].type.should be_nil # Should reset to default
      events[1].data.should eq("second data")
    end

    it "persists last_event_id across events" do
      io = IO::Memory.new("id: 123\ndata: first\n\ndata: second\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(2)
      events[0].id.should eq("123")
      events[1].id.should eq("123") # Should persist
    end

    it "skips events with no data and no type" do
      io = IO::Memory.new("id: 123\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(0)
    end

    it "returns event with type but no data" do
      io = IO::Memory.new("event: heartbeat\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(1)
      events[0].type.should eq("heartbeat")
      events[0].data.should eq("")
    end

    it "parses multiple events" do
      io = IO::Memory.new("data: first\n\ndata: second\n\ndata: third\n\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(3)
      events[0].data.should eq("first")
      events[1].data.should eq("second")
      events[2].data.should eq("third")
    end

    it "handles bare CR line endings" do
      io = IO::Memory.new("data: hello\r\rdata: world\r\r")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(2)
      events[0].data.should eq("hello")
      events[1].data.should eq("world")
    end

    it "handles CRLF line endings" do
      io = IO::Memory.new("data: hello\r\n\r\ndata: world\r\n\r\n")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(2)
      events[0].data.should eq("hello")
      events[1].data.should eq("world")
    end

    it "handles mixed line endings" do
      io = IO::Memory.new("data: lf\n\ndata: crlf\r\n\r\ndata: cr\r\r")
      events = HTTP::EventSource::Parser.new(io).to_a
      events.size.should eq(3)
      events[0].data.should eq("lf")
      events[1].data.should eq("crlf")
      events[2].data.should eq("cr")
    end
  end

  describe HTTP::EventSource::Writer do
    it "formats simple event" do
      io = IO::Memory.new
      writer = HTTP::EventSource::Writer.new(io)
      writer.event(data: "hello")

      io.rewind
      io.gets_to_end.should eq("data: hello\n\n")
    end

    it "formats event with all fields" do
      io = IO::Memory.new
      writer = HTTP::EventSource::Writer.new(io)
      writer.event(data: "test", event: "status", id: "123", retry: 5000)

      io.rewind
      io.gets_to_end.should eq("event: status\nid: 123\nretry: 5000\ndata: test\n\n")
    end

    it "handles multi-line data" do
      io = IO::Memory.new
      writer = HTTP::EventSource::Writer.new(io)
      writer.event(data: "line1\nline2\nline3")

      io.rewind
      io.gets_to_end.should eq("data: line1\ndata: line2\ndata: line3\n\n")
    end

    it "sends comments" do
      io = IO::Memory.new
      writer = HTTP::EventSource::Writer.new(io)
      writer.comment("keep-alive")

      io.rewind
      io.gets_to_end.should eq(":keep-alive\n")
    end

    it "sends empty comment" do
      io = IO::Memory.new
      writer = HTTP::EventSource::Writer.new(io)
      writer.comment

      io.rewind
      io.gets_to_end.should eq(":\n")
    end

    it "sends retry interval" do
      io = IO::Memory.new
      writer = HTTP::EventSource::Writer.new(io)
      writer.retry(5000)

      io.rewind
      io.gets_to_end.should eq("retry: 5000\n\n")
    end
  end

  describe "cookie management" do
    it "parses cookies from initial headers into jar" do
      headers = HTTP::Headers{"Cookie" => "session=abc123; token=xyz"}
      es = HTTP::EventSource.new("http://localhost/events", headers)

      es.cookies.size.should eq(2)
      es.cookies["session"].value.should eq("abc123")
      es.cookies["token"].value.should eq("xyz")
    end

    it "allows setting cookies directly on jar" do
      es = HTTP::EventSource.new("http://localhost/events")
      es.cookies["session"] = "abc123"
      es.cookies["token"] = HTTP::Cookie.new("token", "xyz", secure: true)

      es.cookies.size.should eq(2)
      es.cookies["session"].value.should eq("abc123")
      es.cookies["token"].value.should eq("xyz")
      es.cookies["token"].secure.should be_true
    end

    it "sends cookies in requests" do
      headers_received = Channel(HTTP::Headers).new

      server = HTTP::Server.new do |context|
        headers_received.send(context.request.headers)
        context.response.content_type = "text/event-stream"
        context.response.print("data: test\n\n")
        context.response.close
      end

      address = server.bind_unused_port

      run_server(server) do
        headers = HTTP::Headers{"Cookie" => "session=abc123"}
        es = HTTP::EventSource.new("http://#{address}/events", headers)

        es.on_message do |event|
          es.close
        end

        spawn { es.run }

        request_headers = headers_received.receive
        request_headers["Cookie"].should eq("session=abc123")
      end
    end

    it "stores cookies from Set-Cookie response headers" do
      done = Channel(Nil).new

      server = HTTP::Server.new do |context|
        context.response.content_type = "text/event-stream"
        context.response.cookies << HTTP::Cookie.new("session", "new-session-id")
        context.response.cookies << HTTP::Cookie.new("token", "bearer-xyz")
        context.response.print("data: test\n\n")
        context.response.close
      end

      address = server.bind_unused_port

      run_server(server) do
        es = HTTP::EventSource.new("http://#{address}/events")

        es.on_message do |event|
          es.cookies.size.should eq(2)
          es.cookies["session"].value.should eq("new-session-id")
          es.cookies["token"].value.should eq("bearer-xyz")
          es.close
          done.send(nil)
        end

        spawn { es.run }

        done.receive
      end
    end

    it "sends updated cookies on reconnection" do
      request_count = 0
      cookies_on_second_request = Channel(String?).new

      server = HTTP::Server.new do |context|
        request_count += 1

        if request_count == 1
          # First request: send a cookie
          context.response.content_type = "text/event-stream"
          context.response.cookies << HTTP::Cookie.new("session", "updated-session")
          context.response.status_code = 503 # Trigger reconnection
        else
          # Second request: check if cookie was sent
          cookies_on_second_request.send(context.request.headers["Cookie"]?)
          context.response.content_type = "text/event-stream"
          context.response.print("data: done\n\n")
          context.response.close
        end
      end

      address = server.bind_unused_port

      run_server(server) do
        es = HTTP::EventSource.new("http://#{address}/events")

        es.on_message do |event|
          es.close
        end

        spawn { es.run }

        cookie_header = cookies_on_second_request.receive
        cookie_header.should eq("session=updated-session")
      end
    end

    it "merges initial cookies with Set-Cookie responses" do
      done = Channel(Nil).new

      server = HTTP::Server.new do |context|
        context.response.content_type = "text/event-stream"
        # Server adds a new cookie
        context.response.cookies << HTTP::Cookie.new("server_cookie", "from-server")
        context.response.print("data: test\n\n")
        context.response.close
      end

      address = server.bind_unused_port

      run_server(server) do
        # Start with client cookie
        headers = HTTP::Headers{"Cookie" => "client_cookie=from-client"}
        es = HTTP::EventSource.new("http://#{address}/events", headers)

        es.on_message do |event|
          es.cookies.size.should eq(2)
          es.cookies["client_cookie"].value.should eq("from-client")
          es.cookies["server_cookie"].value.should eq("from-server")
          es.close
          done.send(nil)
        end

        spawn { es.run }

        done.receive
      end
    end

    it "updates existing cookies from Set-Cookie responses" do
      done = Channel(Nil).new

      server = HTTP::Server.new do |context|
        context.response.content_type = "text/event-stream"
        # Update the existing cookie
        context.response.cookies << HTTP::Cookie.new("session", "renewed-session")
        context.response.print("data: test\n\n")
        context.response.close
      end

      address = server.bind_unused_port

      run_server(server) do
        # Start with initial session
        headers = HTTP::Headers{"Cookie" => "session=initial-session"}
        es = HTTP::EventSource.new("http://#{address}/events", headers)

        es.on_message do |event|
          # Cookie should be updated
          es.cookies.size.should eq(1)
          es.cookies["session"].value.should eq("renewed-session")
          es.close
          done.send(nil)
        end

        spawn { es.run }

        done.receive
      end
    end
  end

  describe HTTP::EventSource do
    describe "connection" do
      it "connects and receives events" do
        events_received = [] of HTTP::EventSource::Event
        done = Channel(Nil).new

        server = HTTP::Server.new do |context|
          context.response.content_type = "text/event-stream"
          context.response.headers["Cache-Control"] = "no-cache"

          writer = HTTP::EventSource::Writer.new(context.response)
          writer.event(data: "hello")
          writer.event(event: "custom", data: "world")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            events_received << event
          end

          es.on("custom") do |event|
            events_received << event
            es.close
            done.send(nil)
          end

          spawn { es.run }

          done.receive

          events_received.size.should eq(2)
          events_received[0].data.should eq("hello")
          events_received[0].type.should be_nil
          events_received[1].data.should eq("world")
          events_received[1].type.should eq("custom")
        end
      end

      it "calls on_open callback" do
        opened = Channel(Nil).new

        server = HTTP::Server.new do |context|
          context.response.content_type = "text/event-stream"
          writer = HTTP::EventSource::Writer.new(context.response)
          writer.event(data: "test")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_open do
            opened.send(nil)
          end

          es.on_message do |event|
            es.close
          end

          spawn { es.run }

          opened.receive
        end
      end

      it "updates last_event_id from events" do
        server = HTTP::Server.new do |context|
          context.response.content_type = "text/event-stream"

          writer = HTTP::EventSource::Writer.new(context.response)
          writer.event(data: "test", id: "evt-123")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            es.last_event_id.should eq("evt-123")
            es.close
          end

          es.run
        end
      end

      it "updates retry interval from events" do
        server = HTTP::Server.new do |context|
          context.response.content_type = "text/event-stream"

          writer = HTTP::EventSource::Writer.new(context.response)
          writer.event(data: "test", retry: 7000)
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            event.retry.should eq(7000)
            es.close
          end

          es.run
        end
      end

      it "sets proper request headers" do
        headers_received = Channel(HTTP::Headers).new

        server = HTTP::Server.new do |context|
          headers_received.send(context.request.headers)
          context.response.content_type = "text/event-stream"
          context.response.print("data: test\n\n")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            es.close
          end

          spawn { es.run }

          headers = headers_received.receive
          headers["Accept"].should eq("text/event-stream")
          headers["Cache-Control"].should eq("no-store")
          headers["Connection"].should eq("keep-alive")
        end
      end

      it "sends custom headers" do
        headers_received = Channel(HTTP::Headers).new

        server = HTTP::Server.new do |context|
          headers_received.send(context.request.headers)
          context.response.content_type = "text/event-stream"
          context.response.print("data: test\n\n")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          custom_headers = HTTP::Headers{"Authorization" => "Bearer token123"}
          es = HTTP::EventSource.new("http://#{address}/events", custom_headers)

          es.on_message do |event|
            es.close
          end

          spawn { es.run }

          headers = headers_received.receive
          headers["Authorization"].should eq("Bearer token123")
        end
      end

      it "does not reconnect on 204 No Content" do
        server = HTTP::Server.new do |context|
          context.response.status_code = 204
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.run

          es.closed?.should be_true
          es.ready_state.should eq(HTTP::EventSource::ReadyState::Closed)
        end
      end

      it "does not reconnect on 404 Not Found" do
        server = HTTP::Server.new do |context|
          context.response.status_code = 404
          context.response.print("Not Found")
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          error_raised = false
          es.on_error do |error|
            error.message.to_s.should contain("404")
            error.should be_a(HTTP::EventSource::NoReconnectError)
            error_raised = true
          end

          es.run

          error_raised.should be_true
          es.closed?.should be_true
        end
      end

      it "reconnects on 503 Service Unavailable" do
        request_count = 0
        done = Channel(Nil).new

        server = HTTP::Server.new do |context|
          request_count += 1
          if request_count == 1
            context.response.status_code = 503
          else
            context.response.content_type = "text/event-stream"
            writer = HTTP::EventSource::Writer.new(context.response)
            writer.event(data: "success")
            context.response.close
          end
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            event.data.should eq("success")
            es.close
            done.send(nil)
          end

          spawn { es.run }

          select
          when done.receive
            request_count.should eq(2)
          when timeout(10.seconds)
            fail "Timeout waiting for reconnection"
          end
        end
      end

      it "reconnects on 429 Too Many Requests" do
        request_count = 0
        done = Channel(Nil).new

        server = HTTP::Server.new do |context|
          request_count += 1
          if request_count == 1
            context.response.status_code = 429
          else
            context.response.content_type = "text/event-stream"
            writer = HTTP::EventSource::Writer.new(context.response)
            writer.event(data: "success")
            context.response.close
          end
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            event.data.should eq("success")
            es.close
            done.send(nil)
          end

          spawn { es.run }

          select
          when done.receive
            request_count.should eq(2)
          when timeout(10.seconds)
            fail "Timeout waiting for reconnection"
          end
        end
      end

      it "does not reconnect on invalid content type" do
        server = HTTP::Server.new do |context|
          context.response.content_type = "text/html"
          context.response.print("<html></html>")
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          error_raised = false
          es.on_error do |error|
            error.message.to_s.should contain("Content-Type")
            error.should be_a(HTTP::EventSource::NoReconnectError)
            error_raised = true
          end

          es.run

          error_raised.should be_true
          es.closed?.should be_true
        end
      end

      it "skips events with empty data" do
        events_received = [] of HTTP::EventSource::Event

        server = HTTP::Server.new do |context|
          context.response.content_type = "text/event-stream"

          writer = HTTP::EventSource::Writer.new(context.response)
          # Event with only ID, no data - should be skipped
          writer.event(data: "", id: "123")
          # Event with data - should be received
          writer.event(data: "valid")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_message do |event|
            events_received << event
            es.close
          end

          es.run

          events_received.size.should eq(1)
          events_received[0].data.should eq("valid")
        end
      end
    end

    describe "constructor patterns" do
      it "accepts URI" do
        typeof(HTTP::EventSource.new(URI.parse("http://localhost/events")))
      end

      it "accepts String" do
        typeof(HTTP::EventSource.new("http://localhost/events"))
      end

      it "accepts host and path" do
        typeof(HTTP::EventSource.new("localhost", "/events"))
      end

      it "accepts host, path, and tls" do
        typeof(HTTP::EventSource.new("localhost", "/events", tls: true))
      end

      it "accepts headers" do
        typeof(HTTP::EventSource.new("http://localhost/events",
          HTTP::Headers{"Authorization" => "Bearer token"}))
      end
    end

    describe "ready state" do
      it "starts as Connecting" do
        es = HTTP::EventSource.new("http://localhost/events")
        es.ready_state.should eq(HTTP::EventSource::ReadyState::Connecting)
      end

      it "becomes Open when connected" do
        state_changes = [] of HTTP::EventSource::ReadyState

        server = HTTP::Server.new do |context|
          context.response.content_type = "text/event-stream"
          writer = HTTP::EventSource::Writer.new(context.response)
          writer.event(data: "test")
          context.response.close
        end

        address = server.bind_unused_port

        run_server(server) do
          es = HTTP::EventSource.new("http://#{address}/events")

          es.on_open do
            state_changes << es.ready_state
          end

          es.on_message do |event|
            state_changes << es.ready_state
            es.close
          end

          es.run

          state_changes.should eq([
            HTTP::EventSource::ReadyState::Open,
            HTTP::EventSource::ReadyState::Open,
          ])
        end
      end

      it "becomes Closed when closed" do
        es = HTTP::EventSource.new("http://localhost/events")
        es.close
        es.ready_state.should eq(HTTP::EventSource::ReadyState::Closed)
        es.closed?.should be_true
      end
    end
  end
end
