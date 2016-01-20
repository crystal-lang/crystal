require "spec"
require "http/server"

describe HTTP::StaticFileHandler do
  it "should serve a file" do
    handler = HTTP::StaticFileHandler.new "#{__DIR__}/static"
    response = handler.call HTTP::Request.new("GET", "/test.txt")
    response.status_code.should eq(200)
    response.body.should eq(File.read("#{__DIR__}/static/test.txt"))
  end

  it "should list directory's entries" do
    handler = HTTP::StaticFileHandler.new "#{__DIR__}/static"
    response = handler.call HTTP::Request.new("GET", "/")
    response.status_code.should eq(200)
    response.body.should match(/test.txt/)
  end

  it "shoult not serve not found file" do
    handler = HTTP::StaticFileHandler.new "#{__DIR__}/static"
    response = handler.call HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "should expand a request path" do
    handler = HTTP::StaticFileHandler.new "#{__DIR__}/static"

    # file
    file_text = File.read "#{__DIR__}/static/test.txt"
    %w(../test.txt ../../test.txt test.txt/../test.txt a/./b/../c/../../test.txt).each do |path|
      response = handler.call HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should eq(file_text)
    end

    # directory
    %w(.. ../ ../.. a/.. a/.././b/../).each do |path|
      response = handler.call HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should match(/test.txt/)
    end
  end

  it "should unescape a request path" do
    handler = HTTP::StaticFileHandler.new "#{__DIR__}/static"
    %w(test%2Etxt %2E%2E/test.txt found%2F%2E%2E%2Ftest%2Etxt).each do |path|
      response = handler.call HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/static/test.txt"))
    end
  end

  it "should return 400" do
    handler = HTTP::StaticFileHandler.new "#{__DIR__}/static"
    %w(%00 test.txt%00).each do |path|
      response = handler.call HTTP::Request.new("GET", "/#{path}")
      response.status_code.should eq(400)
    end
  end
end
