require "../../../spec_helper"
require "http/server"

private def handle(request, fallthrough = true, directory_listing = true, ignore_body = false)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = HTTP::StaticFileHandler.new datapath("static_file_handler"), fallthrough, directory_listing
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, ignore_body)
end

describe HTTP::StaticFileHandler do
  file_text = File.read datapath("static_file_handler", "test.txt")

  it "serves a file" do
    response = handle HTTP::Request.new("GET", "/test.txt"), ignore_body: false
    response.status_code.should eq(200)
    response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
  end

  it "adds Etag header" do
    response = handle HTTP::Request.new("GET", "/test.txt")
    response.headers["Etag"].should match(/W\/"\d+"$/)
  end

  it "adds Last-Modified header" do
    response = handle HTTP::Request.new("GET", "/test.txt")
    response.headers["Last-Modified"].should eq(HTTP.format_time(File.info(datapath("static_file_handler", "test.txt")).modification_time))
  end

  context "with If-Modified-Since header" do
    it "returns 304 Not Modified if file mtime is equal" do
      initial_response = handle HTTP::Request.new("GET", "/test.txt")

      headers = HTTP::Headers.new
      headers["If-Modified-Since"] = initial_response.headers["Last-Modified"]

      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: true
      response.status_code.should eq(304)

      response.headers["Last-Modified"].should eq initial_response.headers["Last-Modified"]
      response.headers["Content-Type"]?.should be_nil
    end

    it "returns 304 Not Modified if file mtime is older" do
      headers = HTTP::Headers.new
      headers["If-Modified-Since"] = HTTP.format_time(File.info(datapath("static_file_handler", "test.txt")).modification_time + 1.hour)
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: true

      response.status_code.should eq(304)
    end

    it "serves file if file mtime is younger" do
      headers = HTTP::Headers.new
      headers["If-Modified-Since"] = HTTP.format_time(File.info(datapath("static_file_handler", "test.txt")).modification_time - 1.hour)
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: false

      response.status_code.should eq(200)
      response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
    end
  end

  context "with If-None-Match header" do
    it "returns 304 Not Modified if header matches etag" do
      initial_response = handle HTTP::Request.new("GET", "/test.txt")

      headers = HTTP::Headers.new
      headers["If-None-Match"] = initial_response.headers["Etag"]
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: true
      response.status_code.should eq(304)
    end

    it "serves file if header does not match etag" do
      headers = HTTP::Headers.new
      headers["If-None-Match"] = "some random etag"

      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: false
      response.status_code.should eq(200)
      response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
    end

    it "returns 304 Not Modified if header is *" do
      headers = HTTP::Headers.new
      headers["If-None-Match"] = "*"
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: true
      response.status_code.should eq(304)
    end

    it "serves file if header is empty" do
      headers = HTTP::Headers.new
      headers["If-None-Match"] = ""

      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: false
      response.status_code.should eq(200)
      response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
    end

    it "serves file if header does not contain valid etag" do
      headers = HTTP::Headers.new
      headers["If-None-Match"] = ", foo"

      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: false
      response.status_code.should eq(200)
      response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
    end
  end

  context "with multiple If-None-Match header" do
    it "returns 304 Not Modified if at least one header matches etag" do
      initial_response = handle HTTP::Request.new("GET", "/test.txt")

      headers = HTTP::Headers.new
      headers["If-None-Match"] = %(,, ,W/"1234567"   , , #{initial_response.headers["Etag"]},"12345678",%)
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: true
      response.status_code.should eq(304)
    end

    it "serves file if no header matches etag" do
      headers = HTTP::Headers.new
      headers["If-None-Match"] = "some random etag, 1234567"

      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: false
      response.status_code.should eq(200)
      response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
    end
  end

  context "with both If-None-Match and If-Modified-Since headers" do
    it "ignores If-Modified-Since as specified in RFC 7232" do
      initial_response = handle HTTP::Request.new("GET", "/test.txt")

      headers = HTTP::Headers.new
      headers["If-Modified-Since"] = HTTP.format_time(File.info(datapath("static_file_handler", "test.txt")).modification_time - 1.hour)
      headers["If-None-Match"] = initial_response.headers["Etag"]
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: true

      response.status_code.should eq(304)
    end

    it "serves a file if header does not match etag even If-Modified-Since is fresh" do
      initial_response = handle HTTP::Request.new("GET", "/test.txt")

      headers = HTTP::Headers.new
      headers["If-Modified-Since"] = initial_response.headers["Last-Modified"]
      headers["If-None-Match"] = "some random etag"
      response = handle HTTP::Request.new("GET", "/test.txt", headers), ignore_body: false

      response.status_code.should eq(200)
      response.body.should eq(File.read(datapath("static_file_handler", "test.txt")))
    end
  end

  it "lists directory's entries" do
    response = handle HTTP::Request.new("GET", "/")
    response.status_code.should eq(200)
    response.body.should match(/test.txt/)
  end

  it "does not list directory's entries when directory_listing is set to false" do
    response = handle HTTP::Request.new("GET", "/"), directory_listing: false
    response.status_code.should eq(404)
  end

  it "does not serve a not found file" do
    response = handle HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "does not serve a not found directory" do
    response = handle HTTP::Request.new("GET", "/not_found_dir/")
    response.status_code.should eq(404)
  end

  it "does not serve a file as directory" do
    response = handle HTTP::Request.new("GET", "/test.txt/")
    response.status_code.should eq(404)
  end

  it "handles only GET and HEAD method" do
    %w(GET HEAD).each do |method|
      response = handle HTTP::Request.new(method, "/test.txt")
      response.status_code.should eq(200)
    end

    %w(POST PUT DELETE).each do |method|
      response = handle HTTP::Request.new(method, "/test.txt")
      response.status_code.should eq(404)
      response = handle HTTP::Request.new(method, "/test.txt"), false
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
    end
  end

  it "expands a request path" do
    %w(../test.txt ../../test.txt test.txt/../test.txt a/./b/../c/../../test.txt).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(302)
      response.headers["Location"].should eq("/test.txt")
    end

    # directory
    %w(.. ../ ../.. a/.. a/.././b/../).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(302)
      response.headers["Location"].should eq("/")
    end
  end

  it "unescapes a request path" do
    %w(test%2Etxt %74%65%73%74%2E%74%78%74).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should eq(file_text)
    end

    %w(%2E%2E/test.txt found%2F%2E%2E%2Ftest%2Etxt).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(302)
      response.headers["Location"].should eq("/test.txt")
    end
  end

  it "returns 400" do
    %w(%00 test.txt%00).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(400)
    end
  end

  it "handles invalid redirect path" do
    response = handle HTTP::Request.new("GET", "test.txt%0A")
    response.status_code.should eq(302)
    response.headers["Location"].should eq "/test.txt%0A"

    response = handle HTTP::Request.new("GET", "/test.txt%0A")
    response.status_code.should eq(404)
  end
end
