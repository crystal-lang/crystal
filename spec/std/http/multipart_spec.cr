require "spec"
require "http"

describe HTTP::Multipart do
  describe ".parse" do
    it "parses multipart messages" do
      multipart = "--aA40\r\nContent-Type: text/plain\r\n\r\nabcd\r\n--aA40--"
      HTTP::Multipart.parse(IO::Memory.new(multipart), "aA40") do |headers, io|
        headers["Content-Type"].should eq("text/plain")
        io.gets_to_end.should eq("abcd")
      end
    end
  end

  describe ".parse_boundary" do
    it "parses unquoted boundaries" do
      content_type = "multipart/mixed; boundary=a_-47HDS"
      HTTP::Multipart.parse_boundary(content_type).should eq("a_-47HDS")
    end

    it "parses quoted boundaries" do
      content_type = %{multipart/mixed; boundary="aA_-<>()"}
      HTTP::Multipart.parse_boundary(content_type).should eq(%{aA_-<>()})
    end
  end

  describe ".parse" do
    it "parses multipart messages" do
      headers = HTTP::Headers{"Content-Type" => "multipart/mixed; boundary=aA40"}
      body = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
      request = HTTP::Request.new("POST", "/", headers, body)

      HTTP::Multipart.parse(request) do |headers, io|
        headers["Content-Type"].should eq("text/plain")
        io.gets_to_end.should eq("body")
      end
    end
  end
end
