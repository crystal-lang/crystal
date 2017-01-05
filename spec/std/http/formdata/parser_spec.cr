require "spec"
require "http"

describe HTTP::FormData::Parser do
  it "parses formdata" do
    formdata = <<-FORMDATA
      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="text"

      text
      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="file"; filename="a.txt"
      Content-Type: text/plain

      Content of a.txt.

      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="file2"; filename="a.html"
      Content-Type: text/html

      <!DOCTYPE html><title>Content of a.html.</title>

      -----------------------------735323031399963166993862150--
      FORMDATA

    parser = HTTP::FormData::Parser.new IO::Memory.new(formdata.gsub("\n", "\r\n")), "---------------------------735323031399963166993862150"

    runs = 0
    while parser.has_next?
      parser.next do |part|
        case part.name
        when "text"
          part.body.gets_to_end.should eq("text")
          runs += 1
        when "file"
          part.body.gets_to_end.should eq("Content of a.txt.\r\n")
          part.filename.should eq("a.txt")
          part.headers["Content-Type"].should eq("text/plain")
          runs += 1
        when "file2"
          part.body.gets_to_end.should eq("<!DOCTYPE html><title>Content of a.html.</title>\r\n")
          part.filename.should eq("a.html")
          part.headers["Content-Type"].should eq("text/html")
          runs += 1
        else
          raise "extra field"
        end
      end
    end
    runs.should eq(3)
  end
end
