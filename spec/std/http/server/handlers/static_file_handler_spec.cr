require "spec"
require "http/server"

private def handle(request, fallthrough = true, directory_listing = true)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = HTTP::StaticFileHandler.new "#{__DIR__}/static", fallthrough, directory_listing
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

describe HTTP::StaticFileHandler do
  file_text = File.read "#{__DIR__}/static/test.txt"

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

  it "should not list directory's entries when directory_listing is set to false" do
    response = handle HTTP::Request.new("GET", "/"), directory_listing: false
    response.status_code.should eq(404)
  end

  it "should not serve a not found file" do
    response = handle HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "should not serve a not found directory" do
    response = handle HTTP::Request.new("GET", "/not_found_dir/")
    response.status_code.should eq(404)
  end

  it "should not serve a file as directory" do
    response = handle HTTP::Request.new("GET", "/test.txt/")
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

  it "should unescape a request path" do
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

  it "should return 400" do
    %w(%00 test.txt%00).each do |path|
      response = handle HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(400)
    end
  end
end
