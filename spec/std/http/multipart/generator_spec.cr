require "http"
require "spec"

describe HTTP::Multipart::Generator do
  it "generates valid multipart messages" do
    io = MemoryIO.new
    generator = HTTP::Multipart::Generator.new(io, "fixed-boundary")

    headers = HTTP::Headers{"X-Foo" => "bar"}
    generator.body_part headers, "body part 1"

    headers = HTTP::Headers{"X-Type" => "Empty-Body", "X-Foo" => "Bar"}
    generator.body_part headers

    generator.finish

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
    io = MemoryIO.new
    generator = HTTP::Multipart::Generator.new(io, "fixed-boundary")

    generator.preamble "Here is a preamble to explain why multipart/mixed "
    generator.preamble "exists and why your mail client should support it"

    headers = HTTP::Headers{"X-Foo" => "bar"}
    generator.body_part headers, "body part 1"

    headers = HTTP::Headers{"X-Type" => "Empty-Body", "X-Foo" => "Bar"}
    generator.body_part headers

    generator.epilogue "Irelevant text"
    generator.epilogue "Much more irelevant text"

    generator.finish

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
      generator = HTTP::Multipart::Generator.new(MemoryIO.new, "a delimiter string with a quote in \"")
      generator.content_type("alternative").should eq(%q(multipart/alternative; boundary="a delimiter string with a quote in \""))
    end
  end

  describe ".preamble" do
    it "accepts different data types" do
      io = MemoryIO.new
      generator = HTTP::Multipart::Generator.new(io, "boundary")

      generator.preamble "string\r\n"
      generator.preamble "slice\r\n".to_slice
      preamble_io = MemoryIO.new "io\r\n"
      generator.preamble preamble_io
      generator.preamble do |io|
        io.print "io"
        io << ' '
        io.print "block"
        io << "\r\n"
      end

      generator.body_part(HTTP::Headers.new)
      generator.finish

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
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      generator.body_part HTTP::Headers.new, "test"
      expect_raises(HTTP::Multipart::GenerationException, "Cannot generate preamble: body already started") do
        generator.preamble "test"
      end
    end
  end

  describe ".body_part" do
    it "accepts different data types" do
      io = MemoryIO.new
      generator = HTTP::Multipart::Generator.new(io, "boundary")

      headers = HTTP::Headers{"X-Foo" => "Bar"}

      generator.body_part headers, "string\r\n"
      generator.body_part headers, "slice".to_slice
      body_part_io = MemoryIO.new "io"
      generator.body_part headers, body_part_io
      generator.body_part(headers) do |io|
        io.print "io"
        io << ' '
        io.print "block"
      end
      generator.body_part(headers)

      generator.finish

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
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      generator.body_part HTTP::Headers.new, "test"
      generator.finish
      expect_raises(HTTP::Multipart::GenerationException, "Cannot generate body part: already finished") do
        generator.body_part HTTP::Headers.new, "test"
      end
    end

    it "raises when called after epilogue" do
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      generator.body_part HTTP::Headers.new, "test"
      generator.epilogue "test"
      expect_raises(HTTP::Multipart::GenerationException, "Cannot generate body part: after epilogue") do
        generator.body_part HTTP::Headers.new, "test"
      end
    end
  end

  describe ".epilogue" do
    it "accepts different data types" do
      io = MemoryIO.new
      generator = HTTP::Multipart::Generator.new(io, "boundary")

      generator.body_part(HTTP::Headers.new)

      generator.epilogue "string\r\n"
      generator.epilogue "slice\r\n".to_slice
      epilogue_io = MemoryIO.new "io\r\n"
      generator.epilogue epilogue_io
      generator.epilogue do |io|
        io.print "io"
        io << ' '
        io.print "block"
        io << "\r\n"
      end

      generator.finish

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
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      generator.body_part HTTP::Headers.new, "test"
      generator.finish

      expect_raises(HTTP::Multipart::GenerationException, "Cannot generate epilogue: already finished") do
        generator.epilogue "test"
      end
    end

    it "raises when called with no body parts" do
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      expect_raises(HTTP::Multipart::GenerationException, "Cannot generate epilogue: no body parts") do
        generator.epilogue "test"
      end

      generator.preamble "test"

      expect_raises(HTTP::Multipart::GenerationException, "Cannot generate epilogue: no body parts") do
        generator.epilogue "test"
      end
    end
  end

  describe ".finish" do
    it "raises if no body exists" do
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      expect_raises(HTTP::Multipart::GenerationException, "Cannot finish multipart: no body parts") do
        generator.finish
      end

      generator.preamble "test"

      expect_raises(HTTP::Multipart::GenerationException, "Cannot finish multipart: no body parts") do
        generator.finish
      end
    end

    it "raises if already finished" do
      generator = HTTP::Multipart::Generator.new(MemoryIO.new)

      generator.body_part HTTP::Headers.new, "test"
      generator.finish

      expect_raises(HTTP::Multipart::GenerationException, "Cannot finish multipart: already finished") do
        generator.finish
      end
    end
  end
end
