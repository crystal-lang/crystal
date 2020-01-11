require "spec"
require "http/cookie"

private def parse_first_cookie(header)
  cookies = HTTP::Cookie::Parser.parse_cookies(header)
  cookies.size.should eq(1)
  cookies.first
end

private def parse_set_cookie(header)
  cookie = HTTP::Cookie::Parser.parse_set_cookie(header)
  cookie.should_not be_nil
  cookie.not_nil!
end

module HTTP
  describe Cookie::Parser do
    describe "parse_cookies" do
      it "parses key=value" do
        cookie = parse_first_cookie("key=value")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.to_set_cookie_header.should eq("key=value; path=/")
      end

      it "parse_set_cookie with space" do
        cookie = parse_set_cookie("key=value; path=/test")
        parse_set_cookie("key=value;path=/test").should eq cookie
        parse_set_cookie("key=value;  \t\npath=/test").should eq cookie
      end

      it "parses key=" do
        cookie = parse_first_cookie("key=")
        cookie.name.should eq("key")
        cookie.value.should eq("")
        cookie.to_set_cookie_header.should eq("key=; path=/")
      end

      it "parses key=key=value" do
        cookie = parse_first_cookie("key=key=value")
        cookie.name.should eq("key")
        cookie.value.should eq("key=value")
        cookie.to_set_cookie_header.should eq("key=key%3Dvalue; path=/")
      end

      it "parses key=key%3Dvalue" do
        cookie = parse_first_cookie("key=key%3Dvalue")
        cookie.name.should eq("key")
        cookie.value.should eq("key=value")
        cookie.to_set_cookie_header.should eq("key=key%3Dvalue; path=/")
      end

      it "parses key%3Dvalue=value" do
        cookie = parse_first_cookie("key%3Dvalue=value")
        cookie.name.should eq("key=value")
        cookie.value.should eq("value")
        cookie.to_set_cookie_header.should eq("key%3Dvalue=value; path=/")
      end

      it "parses multiple cookies" do
        cookies = Cookie::Parser.parse_cookies("foo=bar; foobar=baz")
        cookies.size.should eq(2)
        first, second = cookies
        first.name.should eq("foo")
        second.name.should eq("foobar")
        first.value.should eq("bar")
        second.value.should eq("baz")
      end
    end

    describe "parse_set_cookie" do
      it "parses path" do
        cookie = parse_set_cookie("key=value; path=/test")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.path.should eq("/test")
        cookie.to_set_cookie_header.should eq("key=value; path=/test")
      end

      it "parses Secure" do
        cookie = parse_set_cookie("key=value; Secure")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.secure.should be_true
        cookie.to_set_cookie_header.should eq("key=value; path=/; Secure")
      end

      it "parses HttpOnly" do
        cookie = parse_set_cookie("key=value; HttpOnly")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.http_only.should be_true
        cookie.to_set_cookie_header.should eq("key=value; path=/; HttpOnly")
      end

      describe "SameSite" do
        context "Lax" do
          it "parses samesite" do
            cookie = parse_set_cookie("key=value; SameSite=Lax")
            cookie.name.should eq "key"
            cookie.value.should eq "value"
            cookie.samesite.should eq HTTP::Cookie::SameSite::Lax
            cookie.to_set_cookie_header.should eq "key=value; path=/; SameSite=Lax"
          end
        end

        context "Strict" do
          it "parses samesite" do
            cookie = parse_set_cookie("key=value; SameSite=Strict")
            cookie.name.should eq "key"
            cookie.value.should eq "value"
            cookie.samesite.should eq HTTP::Cookie::SameSite::Strict
            cookie.to_set_cookie_header.should eq "key=value; path=/; SameSite=Strict"
          end
        end

        context "Invalid" do
          it "parses samesite" do
            cookie = parse_set_cookie("key=value; SameSite=Foo")
            cookie.name.should eq "key"
            cookie.value.should eq "value"
            cookie.samesite.should be_nil
            cookie.to_set_cookie_header.should eq "key=value; path=/"
          end
        end
      end

      it "parses domain" do
        cookie = parse_set_cookie("key=value; domain=www.example.com")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.domain.should eq("www.example.com")
        cookie.to_set_cookie_header.should eq("key=value; domain=www.example.com; path=/")
      end

      it "parses expires iis" do
        cookie = parse_set_cookie("key=value; expires=Sun, 06-Nov-1994 08:49:37 GMT")
        time = Time.utc(1994, 11, 6, 8, 49, 37)

        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.expires.should eq(time)
      end

      it "parses expires rfc1123" do
        cookie = parse_set_cookie("key=value; expires=Sun, 06 Nov 1994 08:49:37 GMT")
        time = Time.utc(1994, 11, 6, 8, 49, 37)

        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.expires.should eq(time)
      end

      it "parses expires rfc1036" do
        cookie = parse_set_cookie("key=value; expires=Sunday, 06-Nov-94 08:49:37 GMT")
        time = Time.utc(1994, 11, 6, 8, 49, 37)

        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.expires.should eq(time)
      end

      it "parses expires ansi c" do
        cookie = parse_set_cookie("key=value; expires=Sun Nov  6 08:49:37 1994")
        time = Time.utc(1994, 11, 6, 8, 49, 37)

        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.expires.should eq(time)
      end

      it "parses expires ansi c, variant with zone" do
        cookie = parse_set_cookie("bla=; expires=Thu, 01 Jan 1970 00:00:00 -0000")
        cookie.expires.should eq(Time.utc(1970, 1, 1, 0, 0, 0))
      end

      it "parses full" do
        cookie = parse_set_cookie("key=value; path=/test; domain=www.example.com; HttpOnly; Secure; expires=Sun, 06 Nov 1994 08:49:37 GMT; SameSite=Strict")
        time = Time.utc(1994, 11, 6, 8, 49, 37)

        cookie.name.should eq "key"
        cookie.value.should eq "value"
        cookie.path.should eq "/test"
        cookie.domain.should eq "www.example.com"
        cookie.http_only.should be_true
        cookie.secure.should be_true
        cookie.expires.should eq time
        cookie.samesite.should eq HTTP::Cookie::SameSite::Strict
      end

      it "parse domain as IP" do
        parse_set_cookie("a=1; domain=127.0.0.1; path=/; HttpOnly").domain.should eq "127.0.0.1"
      end

      it "parse max-age as seconds from current time" do
        cookie = parse_set_cookie("a=1; max-age=10")
        delta = cookie.expires.not_nil! - Time.utc
        delta.should be > 9.seconds
        delta.should be < 11.seconds

        cookie = parse_set_cookie("a=1; max-age=0")
        delta = Time.utc - cookie.expires.not_nil!
        delta.should be > 0.seconds
        delta.should be < 1.seconds
      end
    end

    describe "expired?" do
      it "by max-age=0" do
        parse_set_cookie("bla=1; max-age=0").expired?.should eq true
      end

      it "by old date" do
        parse_set_cookie("bla=1; expires=Thu, 01 Jan 1970 00:00:00 -0000").expired?.should eq true
      end

      it "not expired" do
        parse_set_cookie("bla=1; max-age=1").expired?.should eq false
      end

      it "not expired" do
        parse_set_cookie("bla=1; expires=Thu, 01 Jan #{Time.utc.year + 2} 00:00:00 -0000").expired?.should eq false
      end

      it "not expired" do
        parse_set_cookie("bla=1").expired?.should eq false
      end
    end
  end

  describe Cookies do
    it "allows adding cookies and retrieving" do
      cookies = Cookies.new
      cookies << Cookie.new("a", "b")
      cookies["c"] = Cookie.new("c", "d")
      cookies["d"] = "e"

      cookies["a"].value.should eq "b"
      cookies["c"].value.should eq "d"
      cookies["d"].value.should eq "e"
      cookies["a"]?.should_not be_nil
      cookies["e"]?.should be_nil
      cookies.has_key?("a").should be_true
    end

    it "allows adding and retrieving cookies with reserved chars" do
      cookies = Cookies.new
      cookies << Cookie.new("a[0]", "b+c%20")
      cookies["d"] = "e+f"

      cookies["a[0]"].value.should eq "b+c%20"
      cookies["d"].value.should eq "e+f"
    end

    it "allows retrieving the size of the cookies collection" do
      cookies = Cookies.new
      cookies.size.should eq 0
      cookies << Cookie.new("1", "2")
      cookies.size.should eq 1
      cookies << Cookie.new("3", "4")
      cookies.size.should eq 2
    end

    it "allows clearing the cookies collection" do
      cookies = Cookies.new
      cookies << Cookie.new("test_key", "test_value")
      cookies << Cookie.new("a", "b")
      cookies << Cookie.new("c", "d")
      cookies.clear
      cookies.should be_empty
    end

    it "allows deleting a particular cookie by key" do
      cookies = Cookies.new
      cookies << Cookie.new("the_key", "the_value")
      cookies << Cookie.new("not_the_key", "not_the_value")
      cookies << Cookie.new("a", "b")
      cookies.has_key?("the_key").should be_true
      cookies.delete("the_key").not_nil!.value.should eq "the_value"
      cookies.has_key?("the_key").should be_false
      cookies.size.should eq 2
    end

    describe "adding request headers" do
      it "overwrites a pre-existing Cookie header" do
        headers = Headers.new
        headers["Cookie"] = "some_key=some_value"

        cookies = Cookies.new
        cookies << Cookie.new("a", "b")

        headers["Cookie"].should eq "some_key=some_value"

        cookies.add_request_headers(headers)

        headers["Cookie"].should eq "a=b"
      end

      it "use encode_www_form to write the cookie's value" do
        headers = Headers.new
        cookies = Cookies.new
        cookies << Cookie.new("a[0]", "b+c")
        cookies.add_request_headers(headers)
        headers["Cookie"].should eq "a%5B0%5D=b%2Bc"
      end

      it "merges multiple cookies into one Cookie header" do
        headers = Headers.new
        cookies = Cookies.new
        cookies << Cookie.new("a", "b")
        cookies << Cookie.new("c", "d")

        cookies.add_request_headers(headers)

        headers["Cookie"].should eq "a=b; c=d"
      end

      describe "when no cookies are set" do
        it "does not set a Cookie header" do
          headers = Headers.new
          headers["Cookie"] = "a=b"
          cookies = Cookies.new

          headers["Cookie"]?.should_not be_nil
          cookies.add_request_headers(headers)
          headers["Cookie"]?.should be_nil
        end
      end
    end

    describe "adding response headers" do
      it "overwrites all pre-existing Set-Cookie headers" do
        headers = Headers.new
        headers.add("Set-Cookie", "a=b; path=/")
        headers.add("Set-Cookie", "c=d; path=/")

        cookies = Cookies.new
        cookies << Cookie.new("x", "y")

        headers.get("Set-Cookie").size.should eq 2
        headers.get("Set-Cookie").includes?("a=b; path=/").should be_true
        headers.get("Set-Cookie").includes?("c=d; path=/").should be_true

        cookies.add_response_headers(headers)

        headers.get("Set-Cookie").size.should eq 1
        headers.get("Set-Cookie")[0].should eq "x=y; path=/"
      end

      it "sets one Set-Cookie header per cookie" do
        headers = Headers.new
        cookies = Cookies.new
        cookies << Cookie.new("a", "b")
        cookies << Cookie.new("c", "d")

        headers.get?("Set-Cookie").should be_nil
        cookies.add_response_headers(headers)
        headers.get?("Set-Cookie").should_not be_nil

        headers.get("Set-Cookie").includes?("a=b; path=/").should be_true
        headers.get("Set-Cookie").includes?("c=d; path=/").should be_true
      end

      it "uses encode_www_form on Set-Cookie" do
        headers = Headers.new
        cookies = Cookies.new
        cookies << Cookie.new("a[0]", "b+c")
        cookies.add_response_headers(headers)
        headers.get("Set-Cookie").includes?("a%5B0%5D=b%2Bc; path=/").should be_true
      end

      describe "when no cookies are set" do
        it "does not set a Set-Cookie header" do
          headers = Headers.new
          headers.add("Set-Cookie", "a=b; path=/")
          cookies = Cookies.new

          headers.get?("Set-Cookie").should_not be_nil
          cookies.add_response_headers(headers)
          headers.get?("Set-Cookie").should be_nil
        end
      end
    end

    it "disallows adding inconsistent state" do
      cookies = Cookies.new

      expect_raises ArgumentError do
        cookies["a"] = Cookie.new("b", "c")
      end
    end

    it "allows to iterate over the cookies" do
      cookies = Cookies.new
      cookies["a"] = "b"
      cookies.each do |cookie|
        cookie.name.should eq "a"
        cookie.value.should eq "b"
      end

      cookie = cookies.each.next
      cookie.should eq Cookie.new("a", "b")
    end

    it "allows transform to hash" do
      cookies = Cookies.new
      cookies << Cookie.new("a", "b")
      cookies["c"] = Cookie.new("c", "d")
      cookies["d"] = "e"
      cookies_hash = cookies.to_h
      compare_hash = {"a" => Cookie.new("a", "b"), "c" => Cookie.new("c", "d"), "d" => Cookie.new("d", "e")}
      cookies_hash.should eq(compare_hash)
      cookies["x"] = "y"
      cookies.to_h.should_not eq(cookies_hash)
    end
  end
end
