require "spec"
require "http"

describe HTTP::FormData do
  describe ".parse(IO, String)" do
    it "parses formdata" do
      formdata = <<-FORMDATA
        --foo
        Content-Disposition: form-data; name="foo"

        bar
        --foo--
        FORMDATA

      res = nil
      HTTP::FormData.parse(IO::Memory.new(formdata.gsub('\n', "\r\n")), "foo") do |part|
        res = part.body.gets_to_end if part.name == "foo"
      end
      res.should eq("bar")
    end
  end

  describe ".parse(HTTP::Request)" do
    it "parses formdata" do
      formdata = <<-FORMDATA
        --foo
        Content-Disposition: form-data; name="foo"

        bar
        --foo--
        FORMDATA
      headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=foo"}
      request = HTTP::Request.new("GET", "/", headers, formdata.gsub('\n', "\r\n"))

      res = nil
      HTTP::FormData.parse(request) do |part|
        res = part.body.gets_to_end if part.name == "foo"
      end
      res.should eq("bar")
    end

    it "raises on empty body" do
      headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=foo"}
      req = HTTP::Request.new("GET", "/", headers)
      expect_raises(HTTP::FormData::Error, "body is empty") do
        HTTP::FormData.parse(req) { }
      end
    end

    it "raises on no Content-Type" do
      req = HTTP::Request.new("GET", "/", body: "")
      expect_raises(HTTP::FormData::Error, "could not find boundary in Content-Type") do
        HTTP::FormData.parse(req) { }
      end
    end

    it "raises on invalid Content-Type" do
      headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary="}
      req = HTTP::Request.new("GET", "/", headers, body: "")
      expect_raises(HTTP::FormData::Error, "could not find boundary in Content-Type") do
        HTTP::FormData.parse(req) { }
      end
    end
  end

  describe ".parse_content_disposition(String)" do
    it "parses all Content-Disposition fields" do
      name, meta = HTTP::FormData.parse_content_disposition %q(form-data; name=foo; filename="foo\"\\bar\ baz\\"; creation-date="Wed, 12 Feb 1997 16:29:51 -0500"; modification-date="12 Feb 1997 16:29:51 -0500"; read-date="Wed, 12 Feb 1997 16:29:51 -0500"; size=432334)

      name.should eq("foo")
      meta.filename.should eq(%q(foo"\bar baz\))
      meta.creation_time.should eq(Time.new(1997, 2, 12, 21, 29, 51, 0, kind: Time::Kind::Utc))
      meta.modification_time.should eq(Time.new(1997, 2, 12, 21, 29, 51, 0, kind: Time::Kind::Utc))
      meta.read_time.should eq(Time.new(1997, 2, 12, 21, 29, 51, 0, kind: Time::Kind::Utc))
      meta.size.should eq(432334)
    end
  end

  describe ".build(IO, String)" do
    it "builds a message" do
      io = IO::Memory.new
      HTTP::FormData.build(io, "boundary") do |g|
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

  describe ".build(HTTP::Response, String)" do
    it "builds a message" do
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      HTTP::FormData.build(response, "boundary") do |g|
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
