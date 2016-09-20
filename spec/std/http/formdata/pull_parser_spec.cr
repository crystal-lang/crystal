require "http"
require "spec"

describe HTTP::FormData::PullParser do
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

    parser = HTTP::FormData::PullParser.new MemoryIO.new(formdata.gsub("\n", "\r\n")), "---------------------------735323031399963166993862150"

    runs = 0
    while parser.has_next?
      parser.next do |field, io, meta, headers|
        case field
        when "text"
          io.gets_to_end.should eq("text")
          runs += 1
        when "file"
          io.gets_to_end.should eq("Content of a.txt.\r\n")
          meta.filename.should eq("a.txt")
          headers["Content-Type"].should eq("text/plain")
          runs += 1
        when "file2"
          io.gets_to_end.should eq("<!DOCTYPE html><title>Content of a.html.</title>\r\n")
          meta.filename.should eq("a.html")
          headers["Content-Type"].should eq("text/html")
          runs += 1
        else
          raise "extra field"
        end
      end
    end
    runs.should eq(3)
  end
end
