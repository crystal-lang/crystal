require "spec"
require "log/spec"
require "http/server/request_processor"
require "../../../support/io"

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
    output.gets_to_end.should eq(requestize(<<-HTTP
      HTTP/1.1 200 OK
      Connection: keep-alive
      Content-Type: text/plain
      Content-Length: 11

      Hello world
      HTTP
    ))
  end

  describe "reads consecutive requests" do
    it "when body is consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response << context.request.body.not_nil!.gets(chomp: true)
        context.response << "\r\n"
      end

      input = IO::Memory.new(requestize(<<-HTTP
        POST / HTTP/1.1
        Content-Length: 7

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        HTTP
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-HTTP
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

        HTTP
      ))
    end

    it "with empty body" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.puts "Hello world\r"
      end

      input = IO::Memory.new(requestize(<<-HTTP
        POST / HTTP/1.1

        POST / HTTP/1.1
        Content-Length: 7

        hello
        HTTP
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-HTTP
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

        HTTP
      ))
    end

    it "fail if body is not consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.puts "Hello world\r"
      end

      input = IO::Memory.new(requestize(<<-HTTP
        POST / HTTP/1.1

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        HTTP
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-HTTP
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 13

        Hello world
        HTTP/1.1 400 Bad Request
        Content-Type: text/plain
        Content-Length: 16

        400 Bad Request\\n
        HTTP
      ).gsub("\\n", "\n"))
    end

    it "closes connection when Connection: close" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.headers["Connection"] = "close"
      end

      input = IO::Memory.new(requestize(<<-HTTP
        POST / HTTP/1.1
        Content-Length: 7

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        HTTP
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-HTTP
        HTTP/1.1 200 OK
        Connection: close
        Content-Length: 0


        HTTP
      ))
    end

    it "closes connection when request body is not entirely consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
      end

      input = IO::Memory.new(requestize(<<-HTTP
        POST / HTTP/1.1
        Content-Length: 4

        1
        POST / HTTP/1.1
        Content-Length: 7

        hello
        HTTP
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-HTTP
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Length: 0


        HTTP
      ))
    end

    it "continues when request body is entirely consumed" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        io = context.request.body.not_nil!
        io.gets_to_end
      end

      input = IO::Memory.new(requestize(<<-HTTP
        POST / HTTP/1.1
        Content-Length: 16387

        #{"0" * 16_384}1
        POST / HTTP/1.1
        Content-Length: 7

        hello
        HTTP
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-HTTP
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Length: 0

        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Length: 0


        HTTP
      ))
    end
  end

  it "handles IO::Error while reading" do
    processor = HTTP::Server::RequestProcessor.new { }
    input = RaiseIOError.new
    output = IO::Memory.new
    processor.process(input, output)
    output.rewind.gets_to_end.should be_empty
  end

  it "handles IO::Error while writing" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world"
      context.response.flush
    end
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = RaiseIOError.new(true)
    logs = Log.capture("http.server") do
      processor.process(input, output)
    end
    logs.check(:debug, "Error while writing data to the client")
    logs.entry.exception.should be_a(IO::Error)
  end

  it "handles IO::Error while flushing" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      context.response.flush
    end
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = RaiseIOError.new(false)
    logs = Log.capture("http.server") do
      processor.process(input, output)
    end
    logs.check(:debug, "Error while flushing data to the client")
    logs.entry.exception.should be_a(IO::Error)
  end

  it "catches raised error on handler and retains context from handler" do
    exception = Exception.new "OH NO"
    processor = HTTP::Server::RequestProcessor.new { Log.context.set foo: "bar"; raise exception }
    input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
    output = IO::Memory.new
    logs = Log.capture("http.server") do
      processor.process(input, output)
    end

    client_response = HTTP::Client::Response.from_io(output.rewind)
    client_response.status_code.should eq(500)
    client_response.status_message.should eq("Internal Server Error")
    client_response.headers["content-type"].should eq("text/plain")
    client_response.headers.has_key?("content-length").should be_true
    client_response.body.should eq("500 Internal Server Error\n")

    logs.check(:error, "Unhandled exception on HTTP::Handler")
    logs.entry.exception.should eq(exception)
    logs.entry.context[:foo].should eq "bar"
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

    client_response = HTTP::Client::Response.from_io(output.rewind)
    client_response.status_code.should eq(200)
    client_response.body.should eq("Hello world")
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

    client_response = HTTP::Client::Response.from_io(output.rewind)
    client_response.status_code.should eq(200)
    client_response.body.should eq("Hello world")
  end

  it "does not bleed Log::Context between requests" do
    processor = HTTP::Server::RequestProcessor.new do |context|
      Log.info { "before" }
      Log.context.set foo: "bar"
      Log.info { "after" }

      context.response.content_type = "text/plain"
      context.response.print "Hello world"
    end

    logs = Log.capture do
      processor.process(
        IO::Memory.new("GET / HTTP/1.1\r\n\r\nGET / HTTP/1.1\r\n\r\n"),
        IO::Memory.new,
      )
    end

    logs.check :info, "before"
    logs.entry.context.should be_empty
    logs.check :info, "after"
    logs.entry.context[:foo].should eq "bar"

    logs.check :info, "before"
    logs.entry.context.should be_empty
    logs.check :info, "after"
    logs.entry.context[:foo].should eq "bar"
  end
end
