require "http"
require "spec"

describe HTTP::FormData do
  describe ".generate(IO, String)" do
    it "generates a message" do
      io = MemoryIO.new
      HTTP::FormData.generate(io, "boundary") do |g|
        g.field("foo", "bar")
      end

      expected = <<-MULTIPART
        --boundary
        Content-Disposition: form-data; name="foo"

        bar
        --boundary--
        MULTIPART
      io.to_s.should eq(expected.gsub('\n', "\r\n"))
    end
  end

  describe ".generate(HTTP::Response, String)" do
    it "generates a message" do
      io = MemoryIO.new
      response = HTTP::Server::Response.new(io)
      HTTP::FormData.generate(response, "boundary") do |g|
        g.field("foo", "bar")
      end
      response.close

      expected = <<-MULTIPART
        HTTP/1.1 200 OK
        Content-Type: multipart/form-data; boundary="boundary"
        Content-Length: 75

        --boundary
        Content-Disposition: form-data; name="foo"

        bar
        --boundary--
        MULTIPART

      io.to_s.should eq(expected.gsub('\n', "\r\n"))
    end
  end
end
