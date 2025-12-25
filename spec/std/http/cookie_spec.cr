require "spec"
require "http/cookie"
require "http/headers"
require "spec/helpers/string"

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

# invalid printable ascii characters, non-printable ascii characters and control characters
private INVALID_COOKIE_VALUES = ("\x00".."\x08").to_a + ("\x0A".."\x1F").to_a + ["\r", "\t", "\n", %(" "), %("), ",", ";", "\\", "\x7f", "\xFF", "🍪"]

module HTTP
  describe Cookie do
    it "#==" do
      cookie = Cookie.new("a", "b", path: "/path", expires: Time.utc, domain: "domain", secure: true, http_only: true, samesite: :strict, extension: "foo=bar")
      cookie.should eq(cookie.dup)
      cookie.should_not eq(cookie.dup.tap { |c| c.name = "c" })
      cookie.should_not eq(cookie.dup.tap { |c| c.value = "c" })
      cookie.should_not eq(cookie.dup.tap { |c| c.path = "/c" })
      cookie.should_not eq(cookie.dup.tap { |c| c.domain = "c" })
      cookie.should_not eq(cookie.dup.tap { |c| c.expires = Time.utc(2021, 1, 1) })
      cookie.should_not eq(cookie.dup.tap { |c| c.secure = false })
      cookie.should_not eq(cookie.dup.tap { |c| c.http_only = false })
      cookie.should_not eq(cookie.dup.tap { |c| c.samesite = :lax })
      cookie.should_not eq(cookie.dup.tap { |c| c.extension = nil })
    end

    describe ".new" do
      it "raises on invalid name" do
        expect_raises IO::Error, "Invalid cookie name" do
          HTTP::Cookie.new("", "")
        end
        expect_raises IO::Error, "Invalid cookie name" do
          HTTP::Cookie.new("\t", "")
        end
      end

      it "raises on invalid value" do
        expect_raises IO::Error, "Invalid cookie value" do
          HTTP::Cookie.new("x", %(foo\rbar))
        end

        INVALID_COOKIE_VALUES.each do |char|
          expect_raises IO::Error, "Invalid cookie value" do
            HTTP::Cookie.new("x", char)
          end
        end
      end

      describe "with a security prefix" do
        it "raises on invalid cookie with prefix" do
          expect_raises ArgumentError, "Invalid cookie name. Has '__Secure-' prefix, but is not secure." do
            HTTP::Cookie.new("__Secure-foo", "bar", secure: false)
          end

          expect_raises ArgumentError, "Invalid cookie name. Does not meet '__Host-' prefix requirements of: secure: true, path: \"/\", domain: nil." do
            HTTP::Cookie.new("__Host-foo", "bar", domain: "foo")
          end
        end

        it "automatically makes the cookie secure if it has the __Secure- prefix and no explicit *secure* value is provided" do
          HTTP::Cookie.new("__Secure-foo", "bar").secure.should be_true
        end

        it "automatically configures the cookie if it has the __Host- prefix and no explicit values provided" do
          cookie = HTTP::Cookie.new "__Host-foo", "bar"
          cookie.secure.should be_true
          cookie.domain.should be_nil
          cookie.path.should eq "/"
        end
      end
    end

    it "#expire" do
      cookie = HTTP::Cookie.new("hello", "world")
      cookie.expire

      cookie.value.empty?.should be_true
      cookie.expired?.should be_true
      cookie.max_age.should eq(Time::Span.zero)
    end

    describe "#name=" do
      it "raises on invalid name" do
        cookie = HTTP::Cookie.new("x", "")
        invalid_names = [
          '"', '(', ')', ',', '/',
          ' ', '\r', '\t', '\n',
          '{', '}',
          (':'..'@').each,
          ('['..']').each,
        ].flat_map { |c| "a#{c}b" }

        # name cannot be empty
        invalid_names << ""

        invalid_names.each do |invalid_name|
          expect_raises IO::Error, "Invalid cookie name" do
            cookie.name = invalid_name
          end
        end
      end

      it "doesn't raise on invalid cookie with __Secure- prefix" do
        cookie = HTTP::Cookie.new "x", "", secure: false

        cookie.name = "__Secure-x"
        cookie.name.should eq "__Secure-x"
        cookie.secure.should be_false
      end

      it "doesn't raise on invalid cookie with __Host- prefix" do
        cookie = HTTP::Cookie.new "x", "", path: "/foo"

        cookie.name = "__Host-x"
        cookie.name.should eq "__Host-x"
        cookie.secure.should be_true
        cookie.path.should eq "/foo"
        cookie.valid?.should be_false
      end

      it "automatically configures the cookie __Secure- prefix and related properties are unset" do
        cookie = HTTP::Cookie.new "x", ""

        cookie.name = "__Secure-x"
        cookie.name.should eq "__Secure-x"
        cookie.secure.should be_true
      end

      it "automatically configures the cookie __Host- prefix and related unset properties" do
        cookie = HTTP::Cookie.new "x", ""

        cookie.name = "__Host-x"
        cookie.name.should eq "__Host-x"
        cookie.secure.should be_true
        cookie.path.should eq "/"
        cookie.domain.should be_nil
      end
    end

    describe "#value=" do
      it "raises on invalid value" do
        cookie = HTTP::Cookie.new("x", "")

        INVALID_COOKIE_VALUES.each do |v|
          expect_raises IO::Error, "Invalid cookie value" do
            cookie.value = "foo#{v}bar"
          end
        end
      end
    end

    describe "#to_set_cookie_header" do
      it { assert_prints HTTP::Cookie.new("x", "v$1").to_set_cookie_header, "x=v$1" }

      it { assert_prints HTTP::Cookie.new("x", "seven", domain: "127.0.0.1").to_set_cookie_header, "x=seven; domain=127.0.0.1" }

      it { assert_prints HTTP::Cookie.new("x", "y", path: "/").to_set_cookie_header, "x=y; path=/" }
      it { assert_prints HTTP::Cookie.new("x", "y", path: "/example").to_set_cookie_header, "x=y; path=/example" }

      it { assert_prints HTTP::Cookie.new("x", "expiring", expires: Time.unix(1257894000)).to_set_cookie_header, "x=expiring; expires=Tue, 10 Nov 2009 23:00:00 GMT" }
      it { assert_prints HTTP::Cookie.new("x", "expiring-1601", expires: Time.utc(1601, 1, 1, 1, 1, 1, nanosecond: 1)).to_set_cookie_header, "x=expiring-1601; expires=Mon, 01 Jan 1601 01:01:01 GMT" }

      it "samesite" do
        assert_prints HTTP::Cookie.new("x", "samesite-default", samesite: nil).to_set_cookie_header, "x=samesite-default"
        assert_prints HTTP::Cookie.new("x", "samesite-lax", samesite: :lax).to_set_cookie_header, "x=samesite-lax; SameSite=Lax"
        assert_prints HTTP::Cookie.new("x", "samesite-strict", samesite: :strict).to_set_cookie_header, "x=samesite-strict; SameSite=Strict"
        assert_prints HTTP::Cookie.new("x", "samesite-none", samesite: :none).to_set_cookie_header, "x=samesite-none; SameSite=None"
      end

      it { assert_prints HTTP::Cookie.new("empty-value", "").to_set_cookie_header, "empty-value=" }
    end

    describe "#to_s" do
      it "stringifies" do
        HTTP::Cookie.new("foo", "bar").to_s.should eq "foo=bar"
        HTTP::Cookie.new("x", "y", domain: "example.com", path: "/foo", expires: Time.unix(1257894000), samesite: :lax).to_s.should eq "x=y; domain=example.com; path=/foo; expires=Tue, 10 Nov 2009 23:00:00 GMT; SameSite=Lax"
      end
    end

    describe "#inspect" do
      it "stringifies" do
        HTTP::Cookie.new("foo", "bar").inspect.should eq %(HTTP::Cookie["foo=bar"])
        HTTP::Cookie.new("x", "y", domain: "example.com", path: "/foo", expires: Time.unix(1257894000), samesite: :lax).inspect.should eq %(HTTP::Cookie["x=y; domain=example.com; path=/foo; expires=Tue, 10 Nov 2009 23:00:00 GMT; SameSite=Lax"])
      end
    end

    describe "#valid? & #validate!" do
      it "raises on invalid cookie with __Secure- prefix" do
        cookie = HTTP::Cookie.new "x", "", secure: false
        cookie.name = "__Secure-x"

        cookie.valid?.should be_false

        expect_raises ArgumentError, "Invalid cookie name. Has '__Secure-' prefix, but is not secure." do
          cookie.validate!
        end

        cookie.secure = true
        cookie.valid?.should be_true
      end

      it "with a __Secure- prefix, but @secure is somehow `nil`" do
        cookie = HTTP::Cookie.new "__Secure-x", ""

        cookie.valid?.should be_true

        pointerof(cookie.@secure).value = nil

        cookie.valid?.should be_false
      end

      it "raises on invalid cookie with __Host- prefix" do
        cookie = HTTP::Cookie.new "x", "", domain: "example.com", secure: false
        cookie.name = "__Host-x"

        cookie.valid?.should be_false

        # Not secure
        expect_raises ArgumentError, "Invalid cookie name. Does not meet '__Host-' prefix requirements of: secure: true, path: \"/\", domain: nil." do
          cookie.validate!
        end

        cookie.secure = true
        cookie.valid?.should be_false

        # Invalid path
        expect_raises ArgumentError, "Invalid cookie name. Does not meet '__Host-' prefix requirements of: secure: true, path: \"/\", domain: nil." do
          cookie.validate!
        end

        cookie.path = "/"
        cookie.valid?.should be_false

        # Has domain
        expect_raises ArgumentError, "Invalid cookie name. Does not meet '__Host-' prefix requirements of: secure: true, path: \"/\", domain: nil." do
          cookie.validate!
        end

        cookie.domain = nil

        cookie.name = "__Host-x"
        cookie.name.should eq "__Host-x"
        cookie.valid?.should be_true
      end
    end
  end

  describe Cookie::Parser do
    describe "parse_cookies" do
      it "parses key=value" do
        cookie = parse_first_cookie("key=value")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.to_set_cookie_header.should eq("key=value")
      end

      it "parses key=" do
        cookie = parse_first_cookie("key=")
        cookie.name.should eq("key")
        cookie.value.should eq("")
        cookie.to_set_cookie_header.should eq("key=")
      end

      it "parses key=key=value" do
        cookie = parse_first_cookie("key=key=value")
        cookie.name.should eq("key")
        cookie.value.should eq("key=value")
        cookie.to_set_cookie_header.should eq("key=key=value")
      end

      it "parses key=key%3Dvalue" do
        cookie = parse_first_cookie("key=key%3Dvalue")
        cookie.name.should eq("key")
        cookie.value.should eq("key%3Dvalue")
        cookie.to_set_cookie_header.should eq("key=key%3Dvalue")
      end

      it "parses special character in name" do
        cookie = parse_first_cookie("key%3Dvalue=value")
        cookie.name.should eq("key%3Dvalue")
        cookie.value.should eq("value")
        cookie.to_set_cookie_header.should eq("key%3Dvalue=value")
      end

      it %(parses key="value") do
        cookie = parse_first_cookie(%(key="value"))
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.to_set_cookie_header.should eq("key=value")
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

      it "parses cookie with spaces in value" do
        parse_first_cookie(%[key=some value]).value.should eq "some value"
        parse_first_cookie(%[key="some value"]).value.should eq "some value"
      end

      it "strips spaces around value only when it's unquoted" do
        parse_first_cookie(%[key= some value  ]).value.should eq "some value"
        parse_first_cookie(%[key=" some value  "]).value.should eq " some value  "
        parse_first_cookie(%[key=  " some value  "  ]).value.should eq " some value  "
      end
    end

    describe "parse_set_cookie" do
      it "with space" do
        cookie = parse_set_cookie("key=value; path=/test")
        parse_set_cookie("key=value;path=/test").should eq cookie
        parse_set_cookie("key=value;  \t\npath=/test").should eq cookie
      end

      it "parses cookie with spaces in value" do
        parse_set_cookie(%[key=some value]).value.should eq "some value"
        parse_set_cookie(%[key="some value"]).value.should eq "some value"
      end

      it "removes leading and trailing whitespaces" do
        cookie = parse_set_cookie(%[key= \tvalue \t;  \t\npath=/test])
        cookie.name.should eq "key"
        cookie.value.should eq "value"
        cookie.path.should eq "/test"

        cookie = parse_set_cookie(%[  key\t  =value \n;path=/test])
        cookie.name.should eq "key"
        cookie.value.should eq "value"
        cookie.path.should eq "/test"
      end

      it "strips spaces around value only when it's unquoted" do
        cookie = parse_set_cookie(%[key= value ;  \tpath=/test])
        cookie.name.should eq "key"
        cookie.value.should eq "value"
        cookie.path.should eq "/test"

        cookie = parse_set_cookie(%[key=" value  ";  \tpath=/test])
        cookie.name.should eq "key"
        cookie.value.should eq " value  "
        cookie.path.should eq "/test"

        cookie = parse_set_cookie(%[key=  " value  "\t ;  \tpath=/test])
        cookie.name.should eq "key"
        cookie.value.should eq " value  "
        cookie.path.should eq "/test"
      end

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
        cookie.to_set_cookie_header.should eq("key=value; Secure")
      end

      it "parses HttpOnly" do
        cookie = parse_set_cookie("key=value; HttpOnly")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.http_only.should be_true
        cookie.to_set_cookie_header.should eq("key=value; HttpOnly")
      end

      describe "SameSite" do
        context "Lax" do
          it "parses samesite" do
            cookie = parse_set_cookie("key=value; SameSite=Lax")
            cookie.name.should eq "key"
            cookie.value.should eq "value"
            cookie.samesite.should eq HTTP::Cookie::SameSite::Lax
            cookie.to_set_cookie_header.should eq "key=value; SameSite=Lax"
          end
        end

        context "Strict" do
          it "parses samesite" do
            cookie = parse_set_cookie("key=value; SameSite=Strict")
            cookie.name.should eq "key"
            cookie.value.should eq "value"
            cookie.samesite.should eq HTTP::Cookie::SameSite::Strict
            cookie.to_set_cookie_header.should eq "key=value; SameSite=Strict"
          end
        end

        context "Invalid" do
          it "parses samesite" do
            cookie = parse_set_cookie("key=value; SameSite=Foo")
            cookie.name.should eq "key"
            cookie.value.should eq "value"
            cookie.samesite.should be_nil
            cookie.to_set_cookie_header.should eq "key=value"
          end
        end
      end

      it "parses domain" do
        cookie = parse_set_cookie("key=value; domain=www.example.com")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.domain.should eq("www.example.com")
        cookie.to_set_cookie_header.should eq("key=value; domain=www.example.com")
      end

      it "leading dots in domain names are ignored" do
        cookie = parse_set_cookie("key=value; domain=.example.com")
        cookie.name.should eq("key")
        cookie.value.should eq("value")
        cookie.domain.should eq("example.com")
        cookie.to_set_cookie_header.should eq("key=value; domain=example.com")
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
        parse_set_cookie("a=1; domain=127.0.0.1; HttpOnly").domain.should eq "127.0.0.1"
      end

      it "parse max-age as Time::Span" do
        cookie = parse_set_cookie("a=1; max-age=10")
        cookie.max_age.should eq 10.seconds

        cookie = parse_set_cookie("a=1; max-age=0")
        cookie.max_age.should eq 0.seconds
      end

      it "parses HttpOnly with trailing semicolon" do
        cookie = parse_set_cookie("test=value; HttpOnly;")
        cookie.name.should eq("test")
        cookie.value.should eq("value")
        cookie.http_only.should be_true
      end

      it "parses Secure with trailing semicolon" do
        cookie = parse_set_cookie("test=value; Secure;")
        cookie.name.should eq("test")
        cookie.value.should eq("value")
        cookie.secure.should be_true
      end

      it "parses both Secure and HttpOnly with trailing semicolon" do
        cookie = parse_set_cookie("test=value; Secure; HttpOnly;")
        cookie.name.should eq("test")
        cookie.value.should eq("value")
        cookie.secure.should be_true
        cookie.http_only.should be_true
      end

      it "parses cookie with multiple trailing semicolons" do
        cookie = parse_set_cookie("test=value; HttpOnly;;")
        cookie.name.should eq("test")
        cookie.value.should eq("value")
        cookie.http_only.should be_true
      end

      it "parses cookie with whitespace and trailing semicolon" do
        cookie = parse_set_cookie("test=value; HttpOnly; ")
        cookie.name.should eq("test")
        cookie.value.should eq("value")
        cookie.http_only.should be_true
      end

      it "parses complex cookie with all attributes and trailing semicolon" do
        cookie = parse_set_cookie("sessionid=abc123; Path=/; Domain=example.com; Expires=Wed, 09 Jun 2021 10:18:14 GMT; Secure; HttpOnly; SameSite=Strict;")
        cookie.name.should eq("sessionid")
        cookie.value.should eq("abc123")
        cookie.path.should eq("/")
        cookie.domain.should eq("example.com")
        cookie.secure.should be_true
        cookie.http_only.should be_true
        cookie.samesite.should eq(HTTP::Cookie::SameSite::Strict)
      end

      it "parses cookie without HttpOnly but with trailing semicolon" do
        cookie = parse_set_cookie("sessionid=abc123; Path=/; Domain=example.com; Secure;")
        cookie.name.should eq("sessionid")
        cookie.value.should eq("abc123")
        cookie.path.should eq("/")
        cookie.domain.should eq("example.com")
        cookie.secure.should be_true
        cookie.http_only.should be_false
      end
    end

    describe "expiration_time" do
      it "sets expiration_time to be current when max-age=0" do
        cookie = parse_set_cookie("bla=1; max-age=0")
        expiration_time = cookie.expiration_time.should_not be_nil
        expiration_time.should be_close(Time.utc, 1.seconds)
      end

      it "sets expiration_time with old date" do
        cookie = parse_set_cookie("bla=1; expires=Thu, 01 Jan 1970 00:00:00 -0000")
        cookie.expiration_time.should eq Time.utc(1970, 1, 1, 0, 0, 0)
      end

      it "sets future expiration_time with max-age" do
        cookie = parse_set_cookie("bla=1; max-age=1")
        cookie.expiration_time.not_nil!.should be > Time.utc
      end

      it "sets future expiration_time with max-age and future cookie creation time" do
        cookie = parse_set_cookie("bla=1; max-age=1")
        cookie_expiration = cookie.expiration_time.should_not be_nil
        cookie_expiration.should be_close(Time.utc, 1.seconds)

        cookie.expired?(time_reference: cookie.creation_time + 1.second).should be_true
      end

      it "sets future expiration_time with expires" do
        cookie = parse_set_cookie("bla=1; expires=Thu, 01 Jan 2020 00:00:00 -0000")
        cookie.expiration_time.should eq Time.utc(2020, 1, 1, 0, 0, 0)
      end

      it "returns nil expiration_time when expires and max-age are not set" do
        cookie = parse_set_cookie("bla=1")
        cookie.expiration_time.should be_nil
      end
    end

    describe "expired?" do
      it "expired when max-age=0" do
        cookie = parse_set_cookie("bla=1; max-age=0")
        cookie.expired?.should be_true
      end

      it "expired with old expires date" do
        cookie = parse_set_cookie("bla=1; expires=Thu, 01 Jan 1970 00:00:00 -0000")
        cookie.expired?.should be_true
      end

      it "not expired with future max-age" do
        cookie = parse_set_cookie("bla=1; max-age=1")
        cookie.expired?.should be_false
      end

      it "not expired with future expires" do
        cookie = parse_set_cookie("bla=1; expires=Thu, 01 Jan #{Time.utc.year + 2} 00:00:00 -0000")
        cookie.expired?.should be_false
      end

      it "not expired when max-age and expires are not provided" do
        cookie = parse_set_cookie("bla=1")
        cookie.expired?.should be_false
      end
    end
  end
end
