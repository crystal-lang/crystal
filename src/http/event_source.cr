require "./client"
require "./headers"
require "./cookie"

# NOTE: To use `EventSource`, you must explicitly import it with `require "http/event_source"`
#
# An EventSource client for Server-Sent Events (SSE).
#
# Server-Sent Events allow servers to push data to clients over a persistent HTTP connection.
# The client receives events as they arrive through lazy iteration.
#
# ```
# require "http/event_source"
#
# # Lazy connection on iteration:
# events = HTTP::EventSource.new("http://example.com/events")
# events.each do |event|
#   puts "Received: #{event.data}"
#   break if event.type == "done"
# end
# events.close
#
# # Eager connection with open block:
# HTTP::EventSource.open("http://example.com/events") do |source, response|
#   puts "Connected! Status: #{response.status_code}"
#   source.each do |event|
#     puts "Event: #{event.type} - #{event.data}"
#     break if event.type == "done"
#   end
# end
# ```
#
# See https://html.spec.whatwg.org/multipage/server-sent-events.html
class HTTP::EventSource
  # Exception raised when an error occurs that should not trigger reconnection.
  class NoReconnectError < Exception
  end

  # :nodoc:
  # Signal sent through the channel when the server gracefully closes (204 No Content).
  private record GracefulStop

  # :nodoc:
  # Signal sent through the channel when a retriable error occurs (IO errors, 429, 5xx).
  private record RetriableError, exception : Exception

  # :nodoc:
  # Signal sent through the channel when a fatal error occurs (4xx, invalid content-type).
  private record FatalError, exception : Exception

  # :nodoc:
  # Union type for all messages sent through the event channel.
  private alias ChannelMessage = Event | GracefulStop | RetriableError | FatalError | Iterator::Stop

  # Represents a Server-Sent Event.
  #
  # Events can have a type (from the `event:` field), data (from `data:` field(s)),
  # an ID (from the `id:` field), and a retry interval (from the `retry:` field).
  record Event,
    # The event type (from "event:" field). When nil, treated as "message".
    type : String? = nil,
    # The event data (from "data:" field(s)), joined with newlines.
    data : String = "",
    # The last event ID (from "id:" field).
    id : String? = nil,
    # Retry interval in milliseconds (from "retry:" field).
    retry : Int32? = nil

  # Make EventSource iterable.
  include Iterator(Event)

  # Connection states matching the W3C EventSource specification.
  enum ReadyState
    # The connection is being established.
    Connecting = 0
    # The connection is open and receiving events.
    Open = 1
    # The connection is closed and will not reconnect.
    Closed = 2
  end

  # Returns the URL used to establish the connection.
  getter url : URI

  # Returns the cookie jar for this EventSource connection.
  #
  # Cookies from the initial request headers are parsed into this jar.
  # Cookies received via `Set-Cookie` response headers are automatically
  # stored and will be sent on subsequent requests and reconnections.
  #
  # ```
  # es = HTTP::EventSource.new(url)
  # es.cookies["session"] = "abc123"
  # es.cookies["token"] = HTTP::Cookie.new("token", "xyz", secure: true)
  # ```
  getter cookies : HTTP::Cookies = HTTP::Cookies.new

  # Returns whether the connection is closed.
  getter? closed = false

  # Returns the current connection state.
  getter ready_state : ReadyState = ReadyState::Connecting

  # Returns the last event ID received, used for reconnection.
  getter last_event_id : String = ""

  # Default reconnection interval in milliseconds.
  DEFAULT_RETRY_INTERVAL = 3000

  @retry_interval : Int32 = DEFAULT_RETRY_INTERVAL
  @original_headers : HTTP::Headers
  @event_channel : Channel(ChannelMessage)?
  @response_channel : Channel(HTTP::Client::Response)?
  @consumer_fiber : Fiber?

  # Opens a new EventSource from a URI.
  #
  # ```
  # require "http/event_source"
  #
  # es = HTTP::EventSource.new(URI.parse("http://example.com/events"))
  # es = HTTP::EventSource.new("http://example.com/events")
  # es = HTTP::EventSource.new("http://example.com/events",
  #   HTTP::Headers{"Authorization" => "Bearer token"})
  # ```
  def self.new(uri : URI | String, headers : HTTP::Headers = HTTP::Headers.new) : self
    uri = URI.parse(uri) if uri.is_a?(String)
    new(uri, headers)
  end

  # Opens a new EventSource to the target host.
  #
  # ```
  # require "http/event_source"
  #
  # es = HTTP::EventSource.new("example.com", "/events")
  # es = HTTP::EventSource.new("example.com", "/events", tls: true)
  # ```
  def self.new(host : String, path : String, port : Int32? = nil,
               tls : HTTP::Client::TLSContext = nil,
               headers : HTTP::Headers = HTTP::Headers.new) : self
    scheme = tls ? "https" : "http"
    port ||= tls ? 443 : 80
    uri = URI.new(scheme: scheme, host: host, port: port, path: path)
    new(uri, headers)
  end

  private def initialize(@url : URI, headers : HTTP::Headers)
    @original_headers = headers

    # Parse any cookies from initial headers into the cookie jar
    @cookies.fill_from_client_headers(headers)
  end

  # Opens an EventSource connection from a URI with eager connection.
  #
  # The connection is established immediately and the block receives the source
  # and the HTTP response. The connection is automatically closed when the block returns.
  #
  # ```
  # require "http/event_source"
  #
  # HTTP::EventSource.open("http://example.com/events") do |source, response|
  #   puts "Connected! Headers: #{response.headers}"
  #   source.each do |event|
  #     puts "Event: #{event.data}"
  #     break if event.type == "done"
  #   end
  # end
  # ```
  def self.open(uri : URI | String, headers : HTTP::Headers = HTTP::Headers.new, &) : Nil
    uri = URI.parse(uri) if uri.is_a?(String)
    source = new(uri, headers)
    begin
      source.open_connection do |response|
        yield source, response
      end
    ensure
      source.close
    end
  end

  # Opens an EventSource connection to the target host with eager connection.
  #
  # ```
  # require "http/event_source"
  #
  # HTTP::EventSource.open("example.com", "/events") do |source, response|
  #   source.each do |event|
  #     puts event.data
  #   end
  # end
  # ```
  def self.open(host : String, path : String, port : Int32? = nil,
                tls : HTTP::Client::TLSContext = nil,
                headers : HTTP::Headers = HTTP::Headers.new, &) : Nil
    scheme = tls ? "https" : "http"
    port ||= tls ? 443 : 80
    uri = URI.new(scheme: scheme, host: host, port: port, path: path)
    open(uri, headers) do |source, response|
      yield source, response
    end
  end

  # :nodoc:
  # Internal method for open() block form - establishes connection eagerly and yields response.
  protected def open_connection(&) : Nil
    # Set up response channel to receive initial response
    @response_channel = Channel(HTTP::Client::Response).new(1)

    # Ensure connection is established
    ensure_connected

    # Wait for initial response from consumer fiber
    response = @response_channel.not_nil!.receive

    # Clear response channel (only needed for initial response)
    @response_channel = nil

    # Yield response to user - they can now call next() to iterate
    yield response
  end

  # Returns the next event from the SSE stream.
  #
  # Automatically connects on first call (for lazy iteration) and handles
  # reconnection transparently. Returns `Iterator::Stop` when the stream is closed.
  #
  # Reconnection behavior:
  # - Network/IO errors: Reconnects after retry interval
  # - 204 No Content: Stops iteration (graceful close)
  # - 4xx errors (except 429): Raises NoReconnectError
  # - 429 Too Many Requests: Reconnects after retry interval
  # - 500, 502, 503, 504: Reconnects after retry interval
  # - Other 5xx errors: Raises NoReconnectError
  def next : Event | Iterator::Stop
    return stop if @closed

    loop do
      # Ensure connection is established (idempotent)
      ensure_connected

      # Receive next event from consumer fiber
      begin
        message = @event_channel.not_nil!.receive
        case message
        when Event
          return message
        when Iterator::Stop
          # Stream ended normally - close and stop (no reconnection)
          close unless @closed
          return stop
        when GracefulStop
          # Graceful close (204 No Content) - close and stop
          close unless @closed
          return stop
        when FatalError
          # Fatal error - close and raise original exception
          close unless @closed
          raise message.exception
        when RetriableError
          # Retriable error - clear fiber and reconnect after delay
          @consumer_fiber = nil
          @event_channel = nil
          return stop if @closed
          sleep @retry_interval.milliseconds
          next
        end
      rescue Channel::ClosedError
        close unless @closed
        return stop
      end
    end
  end

  # Ensures the connection is established, connecting if necessary.
  # Spawns a consumer fiber if not already running.
  private def ensure_connected : Nil
    return if @consumer_fiber
    @event_channel = Channel(ChannelMessage).new(1)
    @consumer_fiber = spawn { consume_stream }
  end

  # :nodoc:
  # Categorizes how to handle an HTTP response.
  private enum ResponseAction
    # 200 OK with valid content-type - continue processing the stream
    Continue
    # 204 No Content - stop gracefully without error
    GracefulStop
    # Retriable errors - 429, 5xx (500, 502, 503, 504), IO errors
    Retriable
    # Fatal errors - 4xx (except 429), invalid content-type, other 5xx
    Fatal
  end

  # Categorizes the HTTP response and returns the action to take.
  # Returns ResponseAction and an optional error message.
  private def categorize_response(response : HTTP::Client::Response) : {ResponseAction, String?}
    status = response.status_code

    # 200 OK - check content type
    if status == 200
      content_type = response.content_type
      unless content_type && content_type.starts_with?("text/event-stream")
        # Invalid content type won't be fixed by retrying
        return {ResponseAction::Fatal, "Invalid Content-Type: expected text/event-stream, got #{content_type}"}
      end
      return {ResponseAction::Continue, nil}
    end

    # 204 No Content - graceful close, don't reconnect
    if status == 204
      return {ResponseAction::GracefulStop, nil}
    end

    # Client errors (4xx) - don't reconnect (except 429)
    if status >= 400 && status < 500
      if status == 429 # Too Many Requests - should retry
        return {ResponseAction::Retriable, "EventSource connection failed: 429 Too Many Requests"}
      else
        # Other 4xx errors won't be fixed by retrying
        return {ResponseAction::Fatal, "EventSource connection failed: #{status}"}
      end
    end

    # Temporary server errors - should reconnect
    if status == 500 || status == 502 || status == 503 || status == 504
      return {ResponseAction::Retriable, "EventSource connection failed: #{status}"}
    end

    # Other errors - don't reconnect
    {ResponseAction::Fatal, "EventSource connection failed: #{status}"}
  end

  # Helper to send a message to the event channel, handling closed channel gracefully.
  private def send_to_channel(message : ChannelMessage) : Nil
    @event_channel.try(&.send(message))
  rescue Channel::ClosedError
    # User stopped iterating, ignore
  end

  # Parses events from the response body and sends them to the channel.
  # Updates last_event_id and retry_interval as events are received.
  private def parse_and_send_events(io : IO) : Nil
    Parser.new(io).each do |event|
      break if @closed

      # Update last event ID if present
      if id = event.id
        @last_event_id = id unless id.empty?
      end

      # Update retry interval if specified
      if retry_val = event.retry
        @retry_interval = retry_val
      end

      # Skip empty data events with no type (per SSE spec)
      next if event.data.empty? && event.type.nil?

      send_to_channel(event)
    end

    # Stream ended normally - send stop
    send_to_channel(Iterator.stop)
  end

  # Connects to server and processes events.
  # Runs in a fiber. The parser iteration blocks on channel.send() until next() receives,
  # so events are only processed when consumed.
  private def consume_stream : Nil
    @ready_state = ReadyState::Connecting
    headers = prepare_headers

    HTTP::Client.get(@url, headers: headers) do |response|
      # Store cookies
      response.cookies.each do |cookie|
        @cookies << cookie
      end

      # Send response if open() is waiting for it
      @response_channel.try(&.send(response))

      # Categorize response and take appropriate action
      action, message = categorize_response(response)

      case action
      in .continue?
        @ready_state = ReadyState::Open
        parse_and_send_events(response.body_io)
      in .graceful_stop?
        send_to_channel(GracefulStop.new)
      in .retriable?
        send_to_channel(RetriableError.new(Exception.new(message.not_nil!)))
      in .fatal?
        send_to_channel(FatalError.new(NoReconnectError.new(message.not_nil!)))
      end
    end
  rescue ex : IO::Error
    # Network errors are retriable
    send_to_channel(RetriableError.new(ex))
  rescue ex
    # Unexpected errors are fatal - re-raise original exception
    send_to_channel(FatalError.new(ex))
  end

  # Prepares request headers for the connection.
  private def prepare_headers : HTTP::Headers
    headers = @original_headers.dup

    # Add cookies from jar to request
    @cookies.add_request_headers(headers)

    headers["Accept"] = "text/event-stream"
    headers["Cache-Control"] = "no-store"
    headers["Connection"] = "keep-alive"

    # Include Last-Event-ID for reconnection
    unless @last_event_id.empty?
      headers["Last-Event-ID"] = @last_event_id
    end

    headers
  end

  # Closes the connection.
  #
  # After calling this method, the EventSource will not reconnect and
  # iteration will stop.
  #
  # ```
  # events = HTTP::EventSource.new("http://example.com/events")
  # events.each do |event|
  #   break if event.type == "done"
  # end
  # events.close
  # ```
  def close : Nil
    return if closed?
    @closed = true
    @ready_state = ReadyState::Closed
    @event_channel.try(&.close)
    @event_channel = nil
    @consumer_fiber = nil
  end

  # :nodoc:
  # Finalizer to ensure connection is closed when GC'd.
  def finalize
    close
  end

  # :nodoc:
  # Parses SSE protocol format from an IO stream.
  class Parser
    include Iterator(Event)

    @event_type : String? = nil
    @data = IO::Memory.new
    @last_event_id : String? = nil
    @retry : Int32? = nil
    @has_data = false
    @peek_byte : UInt8? = nil

    def initialize(@io : IO)
    end

    # Returns the next event from the SSE stream.
    def next : Event | Iterator::Stop
      while line = read_line
        if event = parse_line(line)
          return event
        end
      end
      stop
    end

    # Reads a line from the IO, handling LF, CRLF, and bare CR as line terminators.
    # Per SSE spec, all three are valid line endings.
    # Uses a single-byte lookahead buffer to handle bare CR without seeking.
    private def read_line : String?
      line = String.build do |str|
        loop do
          # Check lookahead buffer first
          byte = @peek_byte || @io.read_byte
          @peek_byte = nil
          return nil if byte.nil?

          case byte
          when '\r'.ord
            # Check if next byte is LF (CRLF sequence)
            next_byte = @io.read_byte
            if next_byte == '\n'.ord
              # CRLF - include both in line
              str << '\r' << '\n'
            elsif next_byte
              # Bare CR - save next byte for next read
              @peek_byte = next_byte
              str << '\r'
            else
              # CR at EOF
              str << '\r'
            end
            break
          when '\n'.ord
            # LF
            str << '\n'
            break
          else
            str << byte.chr
          end
        end
      end

      line.empty? ? nil : line
    end

    # Parses a single line of SSE data.
    # Returns an Event when a complete event is ready (empty line received).
    # Returns nil when more data is needed.
    private def parse_line(line : String) : Event?
      # Remove trailing newline
      line = line.chomp

      # Empty line = dispatch event
      if line.empty?
        return build_event if @has_data || @event_type
      end

      # Comment lines start with ':'
      return nil if line.starts_with?(':')

      # Parse field:value
      if colon_index = line.index(':')
        field = line[0, colon_index]
        # Skip optional space after colon
        value_start = colon_index + 1
        value_start += 1 if value_start < line.size && line[value_start] == ' '
        value = line[value_start..]
      else
        # Line with no colon = field name with empty value
        field = line
        value = ""
      end

      process_field(field, value)
      nil
    end

    private def process_field(field : String, value : String) : Nil
      case field
      when "event"
        @event_type = value
      when "data"
        @data << '\n' if @has_data
        @data << value
        @has_data = true
      when "id"
        # Ignore if contains null character (per spec)
        @last_event_id = value unless value.includes?('\0')
      when "retry"
        if retry_val = value.to_i32?
          @retry = retry_val if retry_val >= 0
        end
      else
        # Unknown fields are ignored per spec
      end
    end

    private def build_event : Event
      event = Event.new(
        type: @event_type,
        data: @data.to_s,
        id: @last_event_id,
        retry: @retry
      )

      # Reset for next event
      @event_type = nil
      @data.clear
      @has_data = false
      # Note: @last_event_id persists across events
      @retry = nil

      event
    end
  end

  # Helper for sending SSE events from a server response.
  #
  # The server should set the following headers for proper SSE behavior:
  # - `Content-Type: text/event-stream`
  # - `Cache-Control: no-cache`
  # - `Connection: keep-alive`
  #
  # ```
  # server = HTTP::Server.new do |context|
  #   context.response.content_type = "text/event-stream"
  #   context.response.headers["Cache-Control"] = "no-cache"
  #   context.response.headers["Connection"] = "keep-alive"
  #
  #   writer = HTTP::EventSource::Writer.new(context.response)
  #   writer.event(data: "Hello!")
  #   writer.event(event: "status", data: "connected")
  # end
  # ```
  class Writer
    def initialize(@io : IO)
    end

    # Sends an event.
    #
    # ```
    # writer.event(data: "Hello world!")
    # writer.event(event: "update", data: "New data", id: "123")
    # writer.event(data: "Multi\nLine\nData")
    # ```
    def event(
      data : String,
      event : String? = nil,
      id : String? = nil,
      retry : Int32? = nil,
    ) : Nil
      @io << "event: " << event << '\n' if event
      @io << "id: " << id << '\n' if id
      @io << "retry: " << retry << '\n' if retry

      # Handle multi-line data
      data.each_line do |line|
        @io << "data: " << line << '\n'
      end

      @io << '\n'
      @io.flush
    end

    # Sends a comment (can be used for keep-alive).
    #
    # ```
    # writer.comment("keep-alive")
    # ```
    def comment(text : String = "") : Nil
      @io << ':' << text << '\n'
      @io.flush
    end

    # Sends a retry interval update.
    #
    # ```
    # writer.retry(5000) # Set retry to 5 seconds
    # ```
    def retry(milliseconds : Int32) : Nil
      @io << "retry: " << milliseconds << '\n'
      @io << '\n'
      @io.flush
    end
  end
end
