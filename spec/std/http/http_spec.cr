require "spec"
require "http"

describe HTTP do
  it "parses RFC 1123" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("Sun, 06 Nov 1994 08:49:37 GMT").should eq(time)
  end

  it "parses RFC 1123 without day name" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("06 Nov 1994 08:49:37 GMT").should eq(time)
  end

  it "parses RFC 1036" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("Sunday, 06-Nov-94 08:49:37 GMT").should eq(time)
  end

  it "parses ANSI C" do
    time = Time.new(1994, 11, 6, 8, 49, 37)
    HTTP.parse_time("Sun Nov  6 08:49:37 1994").should eq(time)
    time2 = Time.new(1994, 11, 16, 8, 49, 37)
    HTTP.parse_time("Sun Nov 16 08:49:37 1994").should eq(time2)
  end

  it "parses and is UTC (#2744)" do
    date = "Mon, 09 Sep 2011 23:36:00 GMT"
    parsed_time = HTTP.parse_time(date).not_nil!
    parsed_time.kind.should eq(Time::Kind::Utc)
  end

  it "parses and is local (#2744)" do
    date = "Mon, 09 Sep 2011 23:36:00 -0300"
    parsed_time = HTTP.parse_time(date).not_nil!
    parsed_time.kind.should eq(Time::Kind::Local)
    parsed_time.to_utc.to_s.should eq("2011-09-10 02:36:00 UTC")
  end

  describe "generates RFC 1123" do
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
        HTTP.rfc1123_date(time).should eq(time.to_utc.to_s("%a, %d %b %Y %H:%M:%S GMT"))
      ensure
        ENV["TZ"] = tz
        LibC.tzset
      end
    end
  end

  describe ".dequote_string" do
    it "dequotes a string" do
      HTTP.dequote_string(%q(foo\"\\bar\ baz\\)).should eq(%q(foo"\bar baz\))
    end
  end

  describe ".quote_string" do
    it "quotes a string" do
      HTTP.quote_string("foo!#():;?~").should eq("foo!#():;?~")
      HTTP.quote_string(%q(foo"bar\baz)).should eq(%q(foo\"bar\\baz))
      HTTP.quote_string("\t ").should eq("\\\t\\ ")
      HTTP.quote_string("it works 😂😂😂👌👌👌😂😂😂").should eq("it\\ works\\ 😂😂😂👌👌👌😂😂😂")
    end

    it "raises on invalid characters" do
      expect_raises(ArgumentError, "String contained invalid character") do
        HTTP.quote_string("foo\0bar")
      end

      expect_raises(ArgumentError, "String contained invalid character") do
        HTTP.quote_string("foo\u{1B}bar")
      end

      expect_raises(ArgumentError, "String contained invalid character") do
        HTTP.quote_string("foo\u{7F}bar")
      end
    end
  end

  describe ".default_status_message_for" do
    it "returns a default message for status 200" do
      HTTP.default_status_message_for(200).should eq("OK")
    end

    it "returns an empty string on non-existent status" do
      HTTP.default_status_message_for(0).should eq("")
    end
  end
end
