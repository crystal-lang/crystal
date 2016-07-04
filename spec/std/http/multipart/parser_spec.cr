require "http"
require "spec"

def mp_parse(delim, data)
  data_io = MemoryIO.new(data.gsub("\n", "\r\n"))
  parser = HTTP::Multipart::Parser.new(data_io, delim)

  parsed = [] of {headers: HTTP::Headers, body: String}
  while parser.has_next?
    parser.next { |h, io| parsed << {headers: h, body: io.gets_to_end} }
  end
  parsed
end

describe HTTP::Multipart::Parser do
  it "parses basic multipart messages" do
    data = mp_parse "AaB03x", <<-MULTIPART
      --AaB03x
      Content-Disposition: form-data; name="submit-name"

      Larry
      --AaB03x
      Content-Disposition: form-data; name="files"; filename="file1.txt"
      Content-Type: text/plain

      ... contents of file1.txt ...
      --AaB03x--
      MULTIPART

    data[0][:body].should eq("Larry")
    data[0][:headers]["Content-Disposition"].should eq("form-data; name=\"submit-name\"")

    data[1][:body].should eq("... contents of file1.txt ...")
    data[1][:headers]["Content-Disposition"].should eq("form-data; name=\"files\"; filename=\"file1.txt\"")
    data[1][:headers]["Content-Type"].should eq("text/plain")
  end

  it "parses messages with preambles and epilogues" do
    data = mp_parse "AaB03x", <<-MULTIPART
      preamble
      AaB03x
      --AaB03x
      Content-Disposition: form-data; name="foo"

      foo
      --AaB03x
      Content-Disposition: form-data; name="bar"

      bar
      --AaB03x--
      AaB03x
      epilogue
      MULTIPART

    data[0][:body].should eq("foo")
    data[0][:headers]["Content-Disposition"].should eq("form-data; name=\"foo\"")

    data[1][:body].should eq("bar")
    data[1][:headers]["Content-Disposition"].should eq("form-data; name=\"bar\"")
  end

  it "raises calling #next after finished" do
    input = <<-MULTIPART
      --AaB03x

      Foo
      --AaB03x--
      MULTIPART
    parser = HTTP::Multipart::Parser.new(MemoryIO.new(input.gsub("\n", "\r\n")), "AaB03x")

    parser.next { }
    parser.has_next?.should eq(false)

    expect_raises(HTTP::Multipart::ParseException, "Multipart parser already finished parsing") do
      parser.next { }
    end
  end

  it "raises calling #next after errored" do
    input = <<-MULTIPART
      --AaB03x
      --AaB03x--
      MULTIPART
    parser = HTTP::Multipart::Parser.new(MemoryIO.new(input.gsub("\n", "\r\n")), "AaB03x")

    expect_raises(HTTP::Multipart::ParseException, "Invalid multipart message") do
      parser.next { }
    end

    parser.has_next?.should eq(false)

    expect_raises(HTTP::Multipart::ParseException, "Multipart parser is in an errored state") do
      parser.next { }
    end
  end

  it "handles break/next in blocks" do
    input = <<-MULTIPART
      --b

      --b

      --b

      --b

      --b--
      MULTIPART

    parser = HTTP::Multipart::Parser.new(MemoryIO.new(input.gsub("\n", "\r\n")), "b")

    ios = [] of IO

    2.times do
      parser.next do |headers, io|
        ios << io
        next
      end
    end

    2.times do
      parser.next do |headers, io|
        ios << io
        break
      end
    end

    parser.@state.should eq(:FINISHED)
    ios.each { |io| io.closed?.should eq(true) }
  end
end
