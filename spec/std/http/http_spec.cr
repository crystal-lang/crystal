require "spec"
require "http"
require "spec/helpers/string"

private def http_quote_string(io : IO, string)
  HTTP.quote_string(string, io)
end

private def http_quote_string(string)
  HTTP.quote_string(string)
end

describe HTTP do
  describe ".parse_time" do
    it "parses RFC 1123" do
      time = Time.utc(1994, 11, 6, 8, 49, 37)
      HTTP.parse_time("Sun, 06 Nov 1994 08:49:37 GMT").should eq(time)
    end

    it "parses RFC 1123 without day name" do
      time = Time.utc(1994, 11, 6, 8, 49, 37)
      HTTP.parse_time("06 Nov 1994 08:49:37 GMT").should eq(time)
    end

    it "parses RFC 1036" do
      time = Time.utc(1994, 11, 6, 8, 49, 37)
      HTTP.parse_time("Sunday, 06-Nov-94 08:49:37 GMT").should eq(time)
    end

    it "parses ANSI C" do
      time = Time.utc(1994, 11, 6, 8, 49, 37)
      HTTP.parse_time("Sun Nov  6 08:49:37 1994").should eq(time)
      time2 = Time.utc(1994, 11, 16, 8, 49, 37)
      HTTP.parse_time("Sun Nov 16 08:49:37 1994").should eq(time2)
    end

    it "parses and is UTC (#2744)" do
      date = "Mon, 09 Sep 2011 23:36:00 GMT"
      parsed_time = HTTP.parse_time(date).not_nil!
      parsed_time.utc?.should be_true
    end

    it "parses and is local (#2744)" do
      date = "Mon, 09 Sep 2011 23:36:00 -0300"
      parsed_time = HTTP.parse_time(date).not_nil!
      parsed_time.offset.should eq -3 * 3600
      parsed_time.to_utc.to_s.should eq("2011-09-10 02:36:00 UTC")
    end

    it "handles errors" do
      HTTP.parse_time("Thu").should be_nil
    end
  end

  describe "generates HTTP date" do
    it "without time zone" do
      time = Time.utc(1994, 11, 6, 8, 49, 37, nanosecond: 0)
      HTTP.format_time(time).should eq("Sun, 06 Nov 1994 08:49:37 GMT")
    end

    it "with local time zone" do
      time = Time.local(1994, 11, 6, 8, 49, 37, nanosecond: 0, location: Time::Location.fixed(3600))
      HTTP.format_time(time).should eq(time.to_utc.to_s("%a, %d %b %Y %H:%M:%S GMT"))
    end
  end

  describe ".dequote_string" do
    it "dequotes a string" do
      HTTP.dequote_string(%q(foo\"\\bar\ baz\\)).should eq(%q(foo"\bar baz\))
    end
  end

  describe ".quote_string" do
    it "quotes a string" do
      assert_prints http_quote_string("foo!#():;?~"), "foo!#():;?~"
      assert_prints http_quote_string(%q(foo"bar\baz)), %q(foo\"bar\\baz)
      assert_prints http_quote_string("\t "), "\\\t\\ "
      assert_prints http_quote_string("it works 😂😂😂👌👌👌😂😂😂"), "it\\ works\\ 😂😂😂👌👌👌😂😂😂"
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
end
