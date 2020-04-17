require "spec"
require "http/server/request_processor"
require "../../../support/log"

private class RaiseIOError < IO
  getter writes = 0

  def initialize(@raise_on_write = false)
  end

  def read(slice : Bytes)
    raise IO::Error.new("...")
  end

  def write(slice : Bytes) : Nil
    @writes += 1
    raise IO::Error.new("...") if @raise_on_write
  end

  def flush
    raise IO::Error.new("...")
  end
end

private def requestize(string)
  string.gsub('\n', "\r\n")
end

describe HTTP::Server::RequestProcessor do
  it "works" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world"
    end

    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = IO::Memory.new
    processor.process(input, output)
    output.rewind
    output.gets_to_end.should eq(requestize(<<-RESPONSE
      HTTP/1.1 200 OK
      Connection: keep-alive
      Content-Type: text/plain
      Content-Length: 11

      Hello world
      RESPONSE
    ))
  end

  describe "reads consecutive requests" do
    it "when body is consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response << context.request.body.not_nil!.gets(chomp: true)
        context.response << "\r\n"
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1
        Content-Length: 7

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 7

        hello
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 7

        hello

        RESPONSE
      ))
    end

    it "with empty body" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.puts "Hello world\r"
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1

        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 13

        Hello world
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 13

        Hello world

        RESPONSE
      ))
    end

    it "fail if body is not consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.puts "Hello world\r"
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 13

        Hello world
        HTTP/1.1 400 Bad Request
        Content-Type: text/plain
        Content-Length: 16

        400 Bad Request\\n
        RESPONSE
      ).gsub("\\n", "\n"))
    end

    it "closes connection when Connection: close" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.headers["Connection"] = "close"
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1
        Content-Length: 7

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: close
        Content-Length: 0


        RESPONSE
      ))
    end

    it "closes connection when request body is not entirely consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1
        Content-Length: 4

        1
        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Length: 0


        RESPONSE
      ))
    end

    it "continues when request body is entirely consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        io = context.request.body.not_nil!
        io.gets_to_end
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1
        Content-Length: 16387

        #{"0" * 16_384}1
        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Length: 0

        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Length: 0


        RESPONSE
      ))
    end
  end

  it "handles IO::Error while reading" do
    processor = HTTP::Server::RequestProcessor.new { }
    input = RaiseIOError.new
    output = IO::Memory.new
    processor.process(input, output)
    output.rewind.gets_to_end.empty?.should be_true
  end

  it "handles IO::Error while writing" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world"
      context.response.flush
    end
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = RaiseIOError.new(true)
    logs = capture_log("http.server", :info) do
      processor.process(input, output)
    end
    logs.should be_empty
  end

  it "handles IO::Error while flushing" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.flush
    end
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = RaiseIOError.new(false)
    logs = capture_log("http.server", :info) do
      processor.process(input, output)
    end
    logs.should be_empty
  end

  it "catches raised error on handler" do
    processor = HTTP::Server::RequestProcessor.new { raise "OH NO" }
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = IO::Memory.new
    logs = capture_log("http.server", :info) do
      processor.process(input, output)
    end
    logs[0].severity.should eq(Log::Severity::Error)
    logs[0].message.should eq("Unhandled exception on HTTP::Handler")
    logs[0].exception.should_not be_nil
    output.rewind.gets_to_end.should match(/Internal Server Error/)
  end

  it "doesn't respond with error when headers were already sent" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world"
      context.response.flush
      raise "OH NO"
    end
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = IO::Memory.new
    processor.process(input, output)
    output.rewind.gets_to_end.should_not match(/Internal Server Error/)
  end

  it "flushes output buffer when an error happens and some content was already sent" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello "
      context.response.flush
      context.response.print "world"
      raise "OH NO"
    end
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = IO::Memory.new
    processor.process(input, output)
    output.rewind.gets_to_end.should match(/world/)
  end
end
