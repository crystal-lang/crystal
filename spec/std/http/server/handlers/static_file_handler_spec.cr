require "spec"
require "http/server"

private def handle(request, fallthrough = true)
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = HTTP::StaticFileHandler.new "#{__DIR__}/static", fallthrough
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

describe HTTP::StaticFileHandler do
  it "should serve a file" do
    response = handle HTTP::Request.new("GET", "/test.txt")
    response.status_code.should eq(200)
    response.body.should eq(File.read("#{__DIR__}/static/test.txt"))
  end

  it "should list directory's entries" do
    response = handle HTTP::Request.new("GET", "/")
    response.status_code.should eq(200)
    response.body.should match(/test.txt/)
  end

  it "shoult not serve not found file" do
    response = handle HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "should handle only GET and HEAD method" do
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

  it "should expand a request path" do
    # file
    file_text = File.read "#{__DIR__}/static/test.txt"
    %w(../test.txt ../../test.txt test.txt/../test.txt a/./b/../c/../../test.txt).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should eq(file_text)
    end

    # directory
    %w(.. ../ ../.. a/.. a/.././b/../).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should match(/test.txt/)
    end
  end

  it "should unescape a request path" do
    %w(test%2Etxt %2E%2E/test.txt found%2F%2E%2E%2Ftest%2Etxt).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/static/test.txt"))
    end
  end

  it "should return 400" do
    %w(%00 test.txt%00).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(400)
    end
  end
end
