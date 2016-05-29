require "spec"
require "http"

describe HTTP do
  it "parses RFC1123" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("Sun, 06 Nov 1994 08:49:37 GMT").should eq(time)
  end

  it "parses RFC1036" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("Sunday, 06-Nov-94 08:49:37 GMT").should eq(time)
  end

  it "parses ANSI C" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("Sun Nov  6 08:49:37 1994").should eq(time)
    time2 = Time.new(1994, 11, 16, 8, 49, 37)
    HTTP.parse_time("Sun Nov 16 08:49:37 1994").should eq(time2)
  end

  describe "generates RFC1123" do
    it "without time zone" do
      time = Time.new(1994, 11, 6, 8, 49, 37, 0, Time::Kind::Utc)
      HTTP.rfc1123_date(time).should eq("Sun, 06 Nov 1994 08:49:37 GMT")
    end

    it "with local time zone" do
      tz = ENV["TZ"]?
      ENV["TZ"] = "Europe/Berlin"
      LibC.tzset
      begin
        time = Time.new(1994, 11, 6, 8, 49, 37, 0, Time::Kind::Local)
        HTTP.rfc1123_date(time).should eq("Sun, 06 Nov 1994 06:49:37 GMT")
      ensure
        ENV["TZ"] = tz
        LibC.tzset
      end
    end
  end
end
