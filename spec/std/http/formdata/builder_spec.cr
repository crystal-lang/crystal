require "spec"
require "http"

describe HTTP::FormData::Builder do
  it "builds valid form-data messages" do
    io = IO::Memory.new
    HTTP::FormData.build(io, "fixed-boundary") do |g|
      g.field("foo", "bar")
      g.field("baz", "qux", HTTP::Headers{"X-Testing" => "headers"})

      body = IO::Memory.new "file content"
      time = Time.new(2016, 1, 1, 12, 0, 0, kind: Time::Kind::Utc)
      metadata = HTTP::FormData::FileMetadata.new("filename.txt \"", time, time, time, 12_u64)
      headers = HTTP::Headers{"Foo" => "Bar", "Baz" => "Qux"}
      g.file("file-test", body, metadata, headers)
    end

    generated = io.to_s
    expected = <<-'MULTIPART'
      --fixed-boundary
      Content-Disposition: form-data; name="foo"

      bar
      --fixed-boundary
      X-Testing: headers
      Content-Disposition: form-data; name="baz"

      qux
      --fixed-boundary
      Foo: Bar
      Baz: Qux
      Content-Disposition: form-data; name="file-test"; filename="filename.txt\ \""; creation-date="Fri, 01 Jan 2016 12:00:00 +0000"; modification-date="Fri, 01 Jan 2016 12:00:00 +0000"; read-date="Fri, 01 Jan 2016 12:00:00 +0000"; size=12

      file content
      --fixed-boundary--
      MULTIPART

    generated.should eq(expected.gsub("\n", "\r\n"))
  end

  describe "#content_type" do
    it "calculates the content type" do
      builder = HTTP::FormData::Builder.new(IO::Memory.new, "a delimiter string with a quote in \"")
      builder.content_type.should eq(%q(multipart/form-data; boundary="a\ delimiter\ string\ with\ a\ quote\ in\ \""))
    end
  end

  describe "#file" do
    it "fails after finish" do
      builder = HTTP::FormData::Builder.new(IO::Memory.new)
      builder.field("foo", "bar")
      builder.finish
      expect_raises(HTTP::FormData::Error, "Cannot add form part: already finished") do
        builder.field("foo", "bar")
      end
    end
  end

  describe "#finish" do
    it "fails after finish" do
      builder = HTTP::FormData::Builder.new(IO::Memory.new)
      builder.field("foo", "bar")
      builder.finish
      expect_raises(HTTP::FormData::Error, "Cannot finish form-data: already finished") do
        builder.finish
      end
    end

    it "fails when no body parts" do
      builder = HTTP::FormData::Builder.new(IO::Memory.new)
      expect_raises(HTTP::FormData::Error, "Cannot finish form-data: no body parts") do
        builder.finish
      end
    end
  end
end
