require "spec"
require "http/cookie"

module HTTP
  describe Cookies do
    describe ".from_client_headers" do
      it "parses Cookie header" do
        cookies = Cookies.from_client_headers Headers{"Cookie" => "a=b"}
        cookies.should eq HTTP::Cookies{Cookie.new("a", "b")}
      end
      it "does not accept Set-Cookie header" do
        cookies = Cookies.from_client_headers Headers{"Cookie" => "a=b", "Set-Cookie" => "x=y"}
        cookies.should eq HTTP::Cookies{Cookie.new("a", "b")}
      end

      it "chops value at the first invalid byte" do
        HTTP::Cookies.from_client_headers(
          HTTP::Headers{"Cookie" => "ginger=snap; cookie=hm🍪delicious; snicker=doodle"}
        ).should eq HTTP::Cookies{
          HTTP::Cookie.new("ginger", "snap"),
          HTTP::Cookie.new("cookie", "hm"),
          HTTP::Cookie.new("snicker", "doodle"),
        }
      end
    end

    describe ".from_server_headers" do
      it "parses Set-Cookie header" do
        cookies = Cookies.from_server_headers Headers{"Set-Cookie" => "a=b; path=/foo"}
        cookies.should eq HTTP::Cookies{Cookie.new("a", "b", path: "/foo")}
      end
      it "does not accept Cookie header" do
        cookies = Cookies.from_server_headers Headers{"Set-Cookie" => "a=b", "Cookie" => "x=y"}
        cookies.should eq HTTP::Cookies{Cookie.new("a", "b")}
      end

      it "drops cookies with invalid byte in value" do
        HTTP::Cookies.from_server_headers(
          HTTP::Headers{"Set-Cookie" => ["ginger=snap", "cookie=hm🍪delicious", "snicker=doodle"]}
        ).should eq HTTP::Cookies{
          HTTP::Cookie.new("ginger", "snap"),
          HTTP::Cookie.new("snicker", "doodle"),
        }
      end
    end

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
        cookies << Cookie.new("a", "b+c")
        cookies.add_request_headers(headers)
        headers["Cookie"].should eq "a=b+c"
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
        headers.add("Set-Cookie", "a=b")
        headers.add("Set-Cookie", "c=d")

        cookies = Cookies.new
        cookies << Cookie.new("x", "y")

        headers.get("Set-Cookie").size.should eq 2
        headers.get("Set-Cookie").should contain("a=b")
        headers.get("Set-Cookie").should contain("c=d")

        cookies.add_response_headers(headers)

        headers.get("Set-Cookie").size.should eq 1
        headers.get("Set-Cookie")[0].should eq "x=y"
      end

      it "sets one Set-Cookie header per cookie" do
        headers = Headers.new
        cookies = Cookies.new
        cookies << Cookie.new("a", "b")
        cookies << Cookie.new("c", "d")

        headers.get?("Set-Cookie").should be_nil
        cookies.add_response_headers(headers)
        headers.get?("Set-Cookie").should_not be_nil

        headers.get("Set-Cookie").should contain("a=b")
        headers.get("Set-Cookie").should contain("c=d")
      end

      it "uses encode_www_form on Set-Cookie value" do
        headers = Headers.new
        cookies = Cookies.new
        cookies << Cookie.new("a", "b+c")
        cookies.add_response_headers(headers)
        headers.get("Set-Cookie").should contain("a=b+c")
      end

      describe "when no cookies are set" do
        it "does not set a Set-Cookie header" do
          headers = Headers.new
          headers.add("Set-Cookie", "a=b")
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

    describe "#==" do
      it "equal" do
        Cookies.new.should eq Cookies.new
        Cookies{Cookie.new("foo", "bar")}.should eq Cookies{Cookie.new("foo", "bar")}
        cookies = Cookies{Cookie.new("foo", "bar"), Cookie.new("baz", "qux")}
        cookies.should eq cookies.dup
      end

      it "order doesn't matter" do
        Cookies{Cookie.new("foo", "bar"), Cookie.new("baz", "qux")}.should eq Cookies{Cookie.new("baz", "qux"), Cookie.new("foo", "bar")}
      end

      it "unequal" do
        Cookies.new.should_not eq Cookies{Cookie.new("foo", "bar")}
        Cookies{Cookie.new("foo", "bar")}.should_not eq Cookies.new

        Cookies{Cookie.new("foo", "bar")}.should_not eq Cookies{Cookie.new("foo", "baz")}
      end
    end

    describe "#to_s" do
      it "stringifies" do
        cookies = HTTP::Cookies{
          HTTP::Cookie.new("foo", "bar"),
          HTTP::Cookie.new("x", "y", domain: "example.com", path: "/foo", expires: Time.unix(1257894000), samesite: :lax),
        }

        cookies.to_s.should eq %(HTTP::Cookies{"foo=bar", "x=y; domain=example.com; path=/foo; expires=Tue, 10 Nov 2009 23:00:00 GMT; SameSite=Lax"})
      end
    end

    describe "#inspect" do
      it "stringifies" do
        cookies = HTTP::Cookies{
          HTTP::Cookie.new("foo", "bar"),
          HTTP::Cookie.new("x", "y", domain: "example.com", path: "/foo", expires: Time.unix(1257894000), samesite: :lax),
        }

        cookies.inspect.should eq %(HTTP::Cookies{"foo=bar", "x=y; domain=example.com; path=/foo; expires=Tue, 10 Nov 2009 23:00:00 GMT; SameSite=Lax"})
      end
    end

    describe "#pretty_print" do
      it "stringifies" do
        cookies = HTTP::Cookies{
          HTTP::Cookie.new("foo", "bar"),
          HTTP::Cookie.new("x", "y", domain: "example.com", path: "/foo", expires: Time.unix(1257894000), samesite: :lax),
        }
        cookies.pretty_inspect.should eq <<-CRYSTAL
          HTTP::Cookies{"foo=bar",
           "x=y; domain=example.com; path=/foo; expires=Tue, 10 Nov 2009 23:00:00 GMT; SameSite=Lax"}
          CRYSTAL
      end
    end
  end
end
