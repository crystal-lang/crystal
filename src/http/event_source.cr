require "./client"
require "./headers"
require "./cookie"

# NOTE: To use `EventSource`, you must explicitly import it with `require "http/event_source"`
#
# An EventSource client for Server-Sent Events (SSE).
#
# Server-Sent Events allow servers to push data to clients over a persistent HTTP connection.
# The client receives events as they arrive and can process them using callbacks.
#
# ```
# require "http/event_source"
#
# es = HTTP::EventSource.new("http://example.com/events")
#
# es.on_message do |event|
#   puts "Received: #{event.data}"
# end
#
# es.on("custom_event") do |event|
#   puts "Custom event: #{event.data}"
# end
#
# es.run # Blocks and receives events
# ```
#
# See https://html.spec.whatwg.org/multipage/server-sent-events.html
class HTTP::EventSource
  # Exception raised when an error occurs that should not trigger reconnection.
  class NoReconnectError < Exception
  end

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
  @headers : HTTP::Headers

  # Callbacks
  @on_open : Proc(Nil)?
  @on_message : Proc(Event, Nil)?
  @on_error : Proc(Exception, Nil)?
  @event_handlers : Hash(String, Array(Proc(Event, Nil)))?

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
    @original_headers = headers.dup
    @headers = headers

    # Parse any cookies from initial headers into the cookie jar
    @cookies.fill_from_client_headers(headers)
  end

  # Called when the connection is established.
  #
  # ```
  # es.on_open do
  #   puts "Connected!"
  # end
  # ```
  def on_open(&@on_open : ->)
  end

  # Called when a message event is received.
  #
  # This is called for events with type "message" or no explicit type.
  #
  # ```
  # es.on_message do |event|
  #   puts "Message: #{event.data}"
  # end
  # ```
  def on_message(&@on_message : Event ->)
  end

  # Called when an error occurs.
  #
  # ```
  # es.on_error do |error|
  #   puts "Error: #{error.message}"
  # end
  # ```
  def on_error(&@on_error : Exception ->)
  end

  # Registers a handler for named events (events with explicit "event:" field).
  #
  # ```
  # es.on("status") do |event|
  #   puts "Status update: #{event.data}"
  # end
  # ```
  def on(event_type : String, &callback : Event ->)
    @event_handlers ||= Hash(String, Array(Proc(Event, Nil))).new
    handlers = @event_handlers.not_nil!
    (handlers[event_type] ||= [] of Proc(Event, Nil)) << callback
  end

  # Starts the event stream and continuously receives events.
  #
  # This method blocks until the connection is closed via `#close`.
  # It automatically reconnects if the connection is lost, using the
  # retry interval specified by the server or the default interval.
  #
  # Reconnection behavior:
  # - Network/IO errors: Reconnects after retry interval
  # - 204 No Content: Closes without reconnecting
  # - 4xx errors (except 429): Closes without reconnecting
  # - 429 Too Many Requests: Reconnects after retry interval
  # - 500, 502, 503, 504: Reconnects after retry interval
  # - Other 5xx errors: Closes without reconnecting
  #
  # ```
  # es = HTTP::EventSource.new("http://example.com/events")
  # es.on_message { |event| puts event.data }
  # es.run # blocks here
  # ```
  def run : Nil
    loop do
      break if closed?

      should_reconnect = false
      begin
        should_reconnect = connect_and_listen
      rescue ex : NoReconnectError
        # Non-retriable error - notify and close
        @on_error.try &.call(ex)
        break
      rescue ex : Exception
        break if closed?
        # Retriable error - notify and reconnect
        @on_error.try &.call(ex)
        should_reconnect = true
      end

      break unless should_reconnect

      # Auto-reconnect after retry interval
      sleep @retry_interval.milliseconds
    end
  end

  # Returns true if should reconnect, false otherwise
  private def connect_and_listen : Bool
    @ready_state = ReadyState::Connecting

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

    HTTP::Client.new(@url) do |client|
      client.get(@url.request_target, headers: headers) do |response|
        # Store cookies from Set-Cookie response headers
        # Do this before validation so cookies are preserved even on error responses
        response.cookies.each do |cookie|
          @cookies << cookie
        end

        should_reconnect = validate_response(response)
        return should_reconnect unless should_reconnect

        @ready_state = ReadyState::Open
        @on_open.try &.call

        Parser.new(response.body_io).each do |event|
          break if closed?
          dispatch_event(event)
        end
      end
    end

    # Connection ended normally (stream closed), reconnect
    true
  end

  # Validates the response.
  # Returns true if the response is valid (200 OK with correct content-type).
  # Raises NoReconnectError for errors that should not trigger reconnection.
  # Raises Exception for errors that should trigger reconnection.
  private def validate_response(response : HTTP::Client::Response) : Bool
    status = response.status_code

    # 200 OK - process the stream
    if status == 200
      content_type = response.content_type
      unless content_type && content_type.starts_with?("text/event-stream")
        # Invalid content type won't be fixed by retrying
        @ready_state = ReadyState::Closed
        @closed = true
        raise NoReconnectError.new("Invalid Content-Type: expected text/event-stream, got #{content_type}")
      end
      return true
    end

    # 204 No Content - graceful close, don't reconnect
    if status == 204
      @ready_state = ReadyState::Closed
      @closed = true
      return false
    end

    # Client errors (4xx) - don't reconnect (except 429)
    if status >= 400 && status < 500
      if status == 429 # Too Many Requests - should retry
        raise "EventSource connection failed: 429 Too Many Requests"
      else
        # Other 4xx errors won't be fixed by retrying
        @ready_state = ReadyState::Closed
        @closed = true
        raise NoReconnectError.new("EventSource connection failed: #{status}")
      end
    end

    # Temporary server errors - should reconnect
    if status == 500 || status == 502 || status == 503 || status == 504
      raise "EventSource connection failed: #{status}"
    end

    # Other errors - don't reconnect
    @ready_state = ReadyState::Closed
    @closed = true
    raise NoReconnectError.new("EventSource connection failed: #{status}")
  end

  private def dispatch_event(event : Event) : Nil
    # Update last event ID if present
    if id = event.id
      @last_event_id = id unless id.empty?
    end

    # Update retry interval if specified
    if retry_val = event.retry
      @retry_interval = retry_val
    end

    # Skip empty data events (per spec)
    return if event.data.empty?

    # Determine event type (default to "message" if nil)
    event_type = event.type || "message"

    # Dispatch to type-specific handlers
    if handlers = @event_handlers.try(&.[event_type]?)
      handlers.each &.call(event)
    end

    # Also dispatch to on_message for "message" type events
    if event_type == "message"
      @on_message.try &.call(event)
    end
  end

  # Closes the connection.
  #
  # After calling this method, the EventSource will not reconnect.
  #
  # ```
  # es.close
  # ```
  def close : Nil
    return if closed?
    @closed = true
    @ready_state = ReadyState::Closed
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
