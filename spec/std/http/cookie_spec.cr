require "spec"
require "http/cookie"

module HTTP
  describe Cookie do
    it "parses key=value" do
      cookie = HTTP::Cookie.parse("key=value")
      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.to_header.should eq("key=value; path=/")
    end

    it "parses key=key=value" do
      cookie = HTTP::Cookie.parse("key=key=value")
      cookie.name.should eq("key")
      cookie.value.should eq("key=value")
      cookie.to_header.should eq("key=key%3Dvalue; path=/")
    end

    it "parses key=key%3Dvalue" do
      cookie = HTTP::Cookie.parse("key=key%3Dvalue")
      cookie.name.should eq("key")
      cookie.value.should eq("key=value")
      cookie.to_header.should eq("key=key%3Dvalue; path=/")
    end

    it "parses path" do
      cookie = HTTP::Cookie.parse("key=value; path=/test")
      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.path.should eq("/test")
      cookie.to_header.should eq("key=value; path=/test")
    end

    it "parses Secure" do
      cookie = HTTP::Cookie.parse("key=value; Secure")
      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.secure.should eq(true)
      cookie.to_header.should eq("key=value; path=/; Secure")
    end

    it "parses HttpOnly" do
      cookie = HTTP::Cookie.parse("key=value; HttpOnly")
      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.http_only.should eq(true)
      cookie.to_header.should eq("key=value; path=/; HttpOnly")
    end

    it "parses domain" do
      cookie = HTTP::Cookie.parse("key=value; domain=www.example.com")
      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.domain.should eq("www.example.com")
      cookie.to_header.should eq("key=value; path=/; domain=www.example.com")
    end

    it "parses expires rfc1123" do
      cookie = HTTP::Cookie.parse("key=value; expires=Sun, 06 Nov 1994 08:49:37 GMT")
      time = Time.new(1994, 11, 6, 8, 49, 37)

      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.expires.should eq(time)
    end

    it "parses expires rfc1036" do
      cookie = HTTP::Cookie.parse("key=value; expires=Sunday, 06-Nov-94 08:49:37 GMT")
      time = Time.new(1994, 11, 6, 8, 49, 37)

      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.expires.should eq(time)
    end

    it "parses expires ansi c" do
      cookie = HTTP::Cookie.parse("key=value; expires=Sun Nov  6 08:49:37 1994")
      time = Time.new(1994, 11, 6, 8, 49, 37)

      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.expires.should eq(time)
    end

    it "parses full" do
      cookie = HTTP::Cookie.parse("key=value; path=/test; domain=www.example.com; HttpOnly; Secure; expires=Sun, 06 Nov 1994 08:49:37 GMT")
      time = Time.new(1994, 11, 6, 8, 49, 37)

      cookie.name.should eq("key")
      cookie.value.should eq("value")
      cookie.path.should eq("/test")
      cookie.domain.should eq("www.example.com")
      cookie.http_only.should eq(true)
      cookie.secure.should eq(true)
      cookie.expires.should eq(time)
    end
  end
end

