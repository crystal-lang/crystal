require "spec"
require "http/server"

private class RaiseErrno
  def initialize(@value : Int32)
  end

  include IO

  def read(slice : Bytes)
    Errno.value = @value
    raise Errno.new "..."
  end

  def write(slice : Bytes) : Nil
    raise "not implemented"
  end
end

private class ReverseResponseOutput
  include IO

  @output : IO

  def initialize(@output : IO)
  end

  def write(slice : Bytes)
    slice.reverse_each do |byte|
      @output.write_byte(byte)
    end
  end

  def read(slice : Bytes)
    raise "Not implemented"
  end

  def close
    @output.close
  end

  def flush
    @output.flush
  end
end

module HTTP
  class Server
    describe Response do
      it "closes" do
        io = IO::Memory.new
        response = Response.new(io)
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      end

      it "prints less then buffer's size" do
        io = IO::Memory.new
        response = Response.new(io)
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "prints less then buffer's size to output" do
        io = IO::Memory.new
        response = Response.new(io)
        response.output.print("Hello")
        response.output.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "prints more then buffer's size" do
        io = IO::Memory.new
        response = Response.new(io)
        str = "1234567890"
        1000.times do
          response.print(str)
        end
        response.close
        first_chunk = str * 819
        second_chunk = str * 181
        io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1ffe\r\n#{first_chunk}\r\n712\r\n#{second_chunk}\r\n0\r\n\r\n")
      end

      it "prints with content length" do
        io = IO::Memory.new
        response = Response.new(io)
        response.headers["Content-Length"] = "10"
        response.print("1234")
        response.print("567890")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n1234567890")
      end

      it "prints with content length (method)" do
        io = IO::Memory.new
        response = Response.new(io)
        response.content_length = 10
        response.print("1234")
        response.print("567890")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n1234567890")
      end

      it "adds header" do
        io = IO::Memory.new
        response = Response.new(io)
        response.headers["Content-Type"] = "text/plain"
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "sets content type" do
        io = IO::Memory.new
        response = Response.new(io)
        response.content_type = "text/plain"
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "changes status and others" do
        io = IO::Memory.new
        response = Response.new(io)
        response.status_code = 404
        response.version = "HTTP/1.0"
        response.close
        io.to_s.should eq("HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n")
      end

      it "flushes" do
        io = IO::Memory.new
        response = Response.new(io)
        response.print("Hello")
        response.flush
        io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n0\r\n\r\n")
      end

      it "wraps output" do
        io = IO::Memory.new
        response = Response.new(io)
        response.output = ReverseResponseOutput.new(response.output)
        response.print("1234")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\n4321")
      end

      it "writes and flushes with HTTP 1.0" do
        io = IO::Memory.new
        response = Response.new(io, "HTTP/1.0")
        response.print("1234")
        response.flush
        io.to_s.should eq("HTTP/1.0 200 OK\r\n\r\n1234")
      end

      it "resets and clears headers and cookies" do
        io = IO::Memory.new
        response = Response.new(io)
        response.headers["Foo"] = "Bar"
        response.cookies["Bar"] = "Foo"
        response.reset
        response.headers.empty?.should be_true
        response.cookies.empty?.should be_true
      end

      it "writes cookie headers" do
        io = IO::Memory.new
        response = Response.new(io)
        response.cookies["Bar"] = "Foo"
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nSet-Cookie: Bar=Foo; path=/\r\n\r\n")

        io = IO::Memory.new
        response = Response.new(io)
        response.cookies["Bar"] = "Foo"
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nSet-Cookie: Bar=Foo; path=/\r\n\r\nHello")
      end

      it "responds with an error" do
        io = IO::Memory.new
        response = Response.new(io)
        response.content_type = "text/html"
        response.respond_with_error
        io.to_s.should eq("HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n1a\r\n500 Internal Server Error\n\r\n")

        io = IO::Memory.new
        response = Response.new(io)
        response.respond_with_error("Bad Request", 400)
        io.to_s.should eq("HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n10\r\n400 Bad Request\n\r\n")
      end
    end
  end

  describe HTTP::Server do
    it "re-sets special port zero after bind" do
      server = Server.new(0) { |ctx| }
      server.bind
      server.port.should_not eq(0)
    end

    it "re-sets port to zero after close" do
      server = Server.new(0) { |ctx| }
      server.bind
      server.close
      server.port.should eq(0)
    end

    it "doesn't raise on accept after close #2692" do
      server = Server.new("0.0.0.0", 0) { }

      spawn do
        server.close
        sleep 0.001
      end

      server.listen
    end

    it "reuses the TCP port (SO_REUSEPORT)" do
      s1 = Server.new(0) { |ctx| }
      s1.bind(reuse_port: true)

      s2 = Server.new(s1.port) { |ctx| }
      s2.bind(reuse_port: true)

      s1.close
      s2.close
    end
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

    it "skips body between requests" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.puts "Hello world\r"
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

    it "handles Errno" do
      processor = HTTP::Server::RequestProcessor.new { }
      input = RaiseErrno.new(Errno::ECONNRESET)
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind.gets_to_end.empty?.should be_true
    end

    it "catches raised error on handler" do
      processor = HTTP::Server::RequestProcessor.new { raise "OH NO" }
      input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
      output = IO::Memory.new
      error = IO::Memory.new
      processor.process(input, output, error)
      output.rewind.gets_to_end.should match(/Internal Server Error/)
    end
  end

  typeof(begin
    # Initialize with custom host
    server = Server.new("0.0.0.0", 0) { |ctx| }
    server.listen
    server.close

    server = Server.new("0.0.0.0", 0, [
      ErrorHandler.new,
      LogHandler.new,
      CompressHandler.new,
      StaticFileHandler.new("."),
    ]
    )
    server.listen
    server.close

    server = Server.new("0.0.0.0", 0, [StaticFileHandler.new(".")]) { |ctx| }
    server.listen
    server.close

    # Initialize with default host
    server = Server.new(0) { |ctx| }
    server.listen
    server.close

    server = Server.new(0, [
      ErrorHandler.new,
      LogHandler.new,
      CompressHandler.new,
      StaticFileHandler.new("."),
    ]
    )
    server.listen
    server.close

    server = Server.new(0, [StaticFileHandler.new(".")]) { |ctx| }
    server.listen
    server.close
  end)
end

private def requestize(string)
  string.gsub("\n", "\r\n")
end
