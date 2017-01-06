require "spec"
require "http"

describe HTTP::Multipart::Builder do
  it "generates valid multipart messages" do
    io = IO::Memory.new
    builder = HTTP::Multipart::Builder.new(io, "fixed-boundary")

    headers = HTTP::Headers{"X-Foo" => "bar"}
    builder.body_part headers, "body part 1"

    headers = HTTP::Headers{"X-Type" => "Empty-Body", "X-Foo" => "Bar"}
    builder.body_part headers

    builder.finish

    expected_message = <<-MULTIPART
      --fixed-boundary
      X-Foo: bar

      body part 1
      --fixed-boundary
      X-Type: Empty-Body
      X-Foo: Bar
      --fixed-boundary--
      MULTIPART

    io.to_s.should eq(expected_message.gsub("\n", "\r\n"))
  end

  it "generates valid multipart messages with preamble and epilogue" do
    io = IO::Memory.new
    builder = HTTP::Multipart::Builder.new(io, "fixed-boundary")

    builder.preamble "Here is a preamble to explain why multipart/mixed "
    builder.preamble "exists and why your mail client should support it"

    headers = HTTP::Headers{"X-Foo" => "bar"}
    builder.body_part headers, "body part 1"

    headers = HTTP::Headers{"X-Type" => "Empty-Body", "X-Foo" => "Bar"}
    builder.body_part headers

    builder.epilogue "Irelevant text"
    builder.epilogue "Much more irelevant text"

    builder.finish

    expected_message = <<-MULTIPART
      Here is a preamble to explain why multipart/mixed exists and why your mail client should support it
      --fixed-boundary
      X-Foo: bar

      body part 1
      --fixed-boundary
      X-Type: Empty-Body
      X-Foo: Bar
      --fixed-boundary--
      Irelevant textMuch more irelevant text
      MULTIPART

    io.to_s.should eq(expected_message.gsub("\n", "\r\n"))
  end

  describe "#content_type" do
    it "calculates the content type" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new, "a delimiter string with a quote in \"")
      builder.content_type("alternative").should eq(%q(multipart/alternative; boundary="a\ delimiter\ string\ with\ a\ quote\ in\ \""))
    end
  end

  describe ".preamble" do
    it "accepts different data types" do
      io = IO::Memory.new
      builder = HTTP::Multipart::Builder.new(io, "boundary")

      builder.preamble "string\r\n"
      builder.preamble "slice\r\n".to_slice
      preamble_io = IO::Memory.new "io\r\n"
      builder.preamble preamble_io
      builder.preamble do |io|
        io.print "io"
        io << ' '
        io.print "block"
        io << "\r\n"
      end

      builder.body_part(HTTP::Headers.new)
      builder.finish

      generated_multipart = io.to_s
      expected_multipart = <<-MULTIPART
        string
        slice
        io
        io block

        --boundary
        --boundary--
        MULTIPART

      generated_multipart.should eq(expected_multipart.gsub("\n", "\r\n"))
    end

    it "raises when called after starting the body" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      builder.body_part HTTP::Headers.new, "test"
      expect_raises(HTTP::Multipart::Error, "Cannot generate preamble: body already started") do
        builder.preamble "test"
      end
    end
  end

  describe ".body_part" do
    it "accepts different data types" do
      io = IO::Memory.new
      builder = HTTP::Multipart::Builder.new(io, "boundary")

      headers = HTTP::Headers{"X-Foo" => "Bar"}

      builder.body_part headers, "string\r\n"
      builder.body_part headers, "slice".to_slice
      body_part_io = IO::Memory.new "io"
      builder.body_part headers, body_part_io
      builder.body_part(headers) do |io|
        io.print "io"
        io << ' '
        io.print "block"
      end
      builder.body_part(headers)

      builder.finish

      generated_multipart = io.to_s
      expected_multipart = <<-MULTIPART
        --boundary
        X-Foo: Bar

        string

        --boundary
        X-Foo: Bar

        slice
        --boundary
        X-Foo: Bar

        io
        --boundary
        X-Foo: Bar

        io block
        --boundary
        X-Foo: Bar
        --boundary--
        MULTIPART

      generated_multipart.should eq(expected_multipart.gsub("\n", "\r\n"))
    end

    it "raises when called after finishing" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      builder.body_part HTTP::Headers.new, "test"
      builder.finish
      expect_raises(HTTP::Multipart::Error, "Cannot generate body part: already finished") do
        builder.body_part HTTP::Headers.new, "test"
      end
    end

    it "raises when called after epilogue" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      builder.body_part HTTP::Headers.new, "test"
      builder.epilogue "test"
      expect_raises(HTTP::Multipart::Error, "Cannot generate body part: after epilogue") do
        builder.body_part HTTP::Headers.new, "test"
      end
    end
  end

  describe ".epilogue" do
    it "accepts different data types" do
      io = IO::Memory.new
      builder = HTTP::Multipart::Builder.new(io, "boundary")

      builder.body_part(HTTP::Headers.new)

      builder.epilogue "string\r\n"
      builder.epilogue "slice\r\n".to_slice
      epilogue_io = IO::Memory.new "io\r\n"
      builder.epilogue epilogue_io
      builder.epilogue do |io|
        io.print "io"
        io << ' '
        io.print "block"
        io << "\r\n"
      end

      builder.finish

      generated_multipart = io.to_s
      expected_multipart = <<-MULTIPART
        --boundary
        --boundary--
        string
        slice
        io
        io block

        MULTIPART

      generated_multipart.should eq(expected_multipart.gsub("\n", "\r\n"))
    end

    it "raises when called after finishing" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      builder.body_part HTTP::Headers.new, "test"
      builder.finish

      expect_raises(HTTP::Multipart::Error, "Cannot generate epilogue: already finished") do
        builder.epilogue "test"
      end
    end

    it "raises when called with no body parts" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      expect_raises(HTTP::Multipart::Error, "Cannot generate epilogue: no body parts") do
        builder.epilogue "test"
      end

      builder.preamble "test"

      expect_raises(HTTP::Multipart::Error, "Cannot generate epilogue: no body parts") do
        builder.epilogue "test"
      end
    end
  end

  describe ".finish" do
    it "raises if no body exists" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      expect_raises(HTTP::Multipart::Error, "Cannot finish multipart: no body parts") do
        builder.finish
      end

      builder.preamble "test"

      expect_raises(HTTP::Multipart::Error, "Cannot finish multipart: no body parts") do
        builder.finish
      end
    end

    it "raises if already finished" do
      builder = HTTP::Multipart::Builder.new(IO::Memory.new)

      builder.body_part HTTP::Headers.new, "test"
      builder.finish

      expect_raises(HTTP::Multipart::Error, "Cannot finish multipart: already finished") do
        builder.finish
      end
    end
  end
end
