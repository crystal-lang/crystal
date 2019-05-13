require "spec"
require "uri"

private def assert_uri(string, file = __FILE__, line = __LINE__, **args)
  it "`#{string}`", file, line do
    URI.parse(string).should eq URI.new(**args)
    URI.parse(string).to_s.should eq string
  end
end

describe "URI" do
  describe ".parse" do
    # scheme
    assert_uri("http:", scheme: "http")
    it { URI.parse("HttP:").should eq(URI.new(scheme: "http")) }

    # host
    assert_uri("http://www.example.com", scheme: "http", host: "www.example.com")
    assert_uri("http://www.foo-bar.example.com", scheme: "http", host: "www.foo-bar.example.com")
    assert_uri("http://www.example.com:81", scheme: "http", host: "www.example.com", port: 81)
    assert_uri("http://[::1]:81", scheme: "http", host: "[::1]", port: 81)
    assert_uri("http://192.0.2.16:81", scheme: "http", host: "192.0.2.16", port: 81)
    it { URI.parse("http://[fe80::1%en0]:8080/").should eq(URI.new(scheme: "http", host: "[fe80::1%en0]", port: 8080, path: "/")) }
    assert_uri("http://[fe80::1%25en0]:8080/", scheme: "http", host: "[fe80::1%en0]", port: 8080, path: "/")
    assert_uri("mysql://a,b,c/bar", scheme: "mysql", host: "a,b,c", path: "/bar")
    assert_uri("scheme://!$&'()*+,;=hello!:12/path", scheme: "scheme", host: "!$&'()*+,;=hello!", port: 12, path: "/path")
    it { URI.parse("http://hello.世界.com").should eq(URI.new(scheme: "http", host: "hello.世界.com")) }
    assert_uri("tcp://[2020::2020:20:2020:2020%25Windows%20Loves%20Spaces]:2020", scheme: "tcp", host: "[2020::2020:20:2020:2020%Windows Loves Spaces]", port: 2020)

    # host with trailing slash
    assert_uri("http://www.example.com/", scheme: "http", host: "www.example.com", path: "/")
    assert_uri("http://www.example.com:81/", scheme: "http", host: "www.example.com", port: 81, path: "/")
    assert_uri("http://[::1]:81/", scheme: "http", host: "[::1]", port: 81, path: "/")
    assert_uri("http://192.0.2.16:81/", scheme: "http", host: "192.0.2.16", port: 81, path: "/")

    # port
    it { URI.parse("http://192.168.0.2:/foo").should eq URI.new(scheme: "http", host: "192.168.0.2", path: "/foo") }

    # path
    assert_uri("http://www.example.com/foo", scheme: "http", host: "www.example.com", path: "/foo")
    assert_uri("http:.", scheme: "http", path: ".")
    assert_uri("http:..", scheme: "http", path: "..")
    assert_uri("http://host/!$&'()*+,;=:@[hello]", scheme: "http", host: "host", path: "/!$&'()*+,;=:@[hello]")
    assert_uri("http://example.com//foo", scheme: "http", host: "example.com", path: "//foo")
    assert_uri("///foo", host: "", path: "/foo")

    pending "path with escape" do
      assert_uri("http://www.example.com/file%20one%26two", scheme: "http", host: "example.com", path: "/file one&two", raw_path: "/file%20one%26two")
    end

    # query
    assert_uri("http://www.example.com/foo?q=1", scheme: "http", host: "www.example.com", path: "/foo", query: "q=1")
    assert_uri("http://www.example.com/foo?", scheme: "http", host: "www.example.com", path: "/foo", query: "")
    assert_uri("?q=1", query: "q=1")
    assert_uri("?q=1?", query: "q=1?")
    assert_uri("?a+b=c%2Bd", query: "a+b=c%2Bd")
    assert_uri("?query=http://example.com", query: "query=http://example.com")

    # userinfo
    assert_uri("https://alice:pa55w0rd@www.example.com", scheme: "https", host: "www.example.com", user: "alice", password: "pa55w0rd")
    assert_uri("https://alice@www.example.com", scheme: "https", host: "www.example.com", user: "alice", password: nil)
    assert_uri("https://alice:@www.example.com", scheme: "https", host: "www.example.com", user: "alice", password: "")
    assert_uri("https://%3AD:%40_%40@www.example.com", scheme: "https", host: "www.example.com", user: ":D", password: "@_@")

    pending "unescaped @ in user/password should not confuse host" do
      assert_uri("http://j@ne:password@example.com", scheme: "http", host: "example.com", user: "j@ne", password: "password")
      assert_uri("http://jane:p@ssword@example.com", scheme: "http", host: "example.com", user: "jane", password: "p@ssword")
    end

    # fragment
    assert_uri("https://www.example.com/#top", scheme: "https", host: "www.example.com", path: "/", fragment: "top")

    # relative URL
    assert_uri("/foo", path: "/foo")
    assert_uri("/foo?q=1", path: "/foo", query: "q=1")
    assert_uri("//foo", host: "foo")
    assert_uri("//user@foo/path?q=b", host: "foo", user: "user", path: "/path", query: "q=b")

    # various schemes
    assert_uri("mailto:foo@example.org", scheme: "mailto", path: "foo@example.org")
    assert_uri("news:comp.infosystems.www.servers.unix", scheme: "news", path: "comp.infosystems.www.servers.unix")
    assert_uri("tel:+1-816-555-1212", scheme: "tel", path: "+1-816-555-1212")
    assert_uri("urn:oasis:names:specification:docbook:dtd:xml:4.1.2", scheme: "urn", path: "oasis:names:specification:docbook:dtd:xml:4.1.2")
    assert_uri("telnet://192.0.2.16:80/", scheme: "telnet", host: "192.0.2.16", port: 80, path: "/")
    assert_uri("ldap://[2001:db8::7]/c=GB?objectClass?one", scheme: "ldap", host: "[2001:db8::7]", path: "/c=GB", query: "objectClass?one")
    assert_uri("magnet:?xt=urn:btih:c12fe1c06bba254a9dc9f519b335aa7c1367a88a&dn", scheme: "magnet", query: "xt=urn:btih:c12fe1c06bba254a9dc9f519b335aa7c1367a88a&dn")

    # opaque
    assert_uri("http:example.com/?q=foo", scheme: "http", path: "example.com/", query: "q=foo")

    # no hierarchical part
    assert_uri("http:", scheme: "http")
    assert_uri("http:?", scheme: "http", query: "")
    assert_uri("http:?#", scheme: "http", query: "", fragment: "")
    assert_uri("http:#", scheme: "http", fragment: "")
    assert_uri("http://", scheme: "http", host: "")
    assert_uri("http://?", scheme: "http", host: "", query: "")
    assert_uri("http://?#", scheme: "http", host: "", query: "", fragment: "")
    assert_uri("http://#", scheme: "http", host: "", fragment: "")

    # empty host, but port
    assert_uri("http://:8000", scheme: "http", host: "", port: 8000)
    assert_uri("http://:8000/foo", scheme: "http", host: "", port: 8000, path: "/foo")

    # empty host, but user
    assert_uri("http://user@", scheme: "http", host: "", user: "user")
    assert_uri("http://user@/foo", scheme: "http", host: "", user: "user", path: "/foo")

    # path with illegal characters
    assert_uri("foo/another@url/[]and{}", path: "foo/another@url/[]and{}")

    # complex examples
    assert_uri("http://user:pass@bitfission.com:8080/path?a=b#frag",
      scheme: "http", user: "user", password: "pass", host: "bitfission.com", port: 8080, path: "/path", query: "a=b", fragment: "frag")
    assert_uri("//user:pass@bitfission.com:8080/path?a=b#frag",
      user: "user", password: "pass", host: "bitfission.com", port: 8080, path: "/path", query: "a=b", fragment: "frag")
    assert_uri("/path?a=b#frag", path: "/path", query: "a=b", fragment: "frag")
    assert_uri("file://localhost/etc/fstab", scheme: "file", host: "localhost", path: "/etc/fstab")
    assert_uri("file:///etc/fstab", scheme: "file", host: "", path: "/etc/fstab")
    assert_uri("file:///C:/FooBar/Baz.txt", scheme: "file", host: "", path: "/C:/FooBar/Baz.txt")
    assert_uri("test:/test", scheme: "test", path: "/test")

    context "bad urls" do
      it { expect_raises(URI::Error) { URI.parse("http://some.com:8f80/path") } }
    end
  end

  describe "hostname" do
    it { URI.new("http", "www.example.com", path: "/foo").hostname.should eq("www.example.com") }
    it { URI.new("http", "[::1]", path: "foo").hostname.should eq("::1") }
    it { URI.new(path: "/foo").hostname.should be_nil }
  end

  describe "full_path" do
    it { URI.new(path: "/foo").full_path.should eq("/foo") }
    it { URI.new.full_path.should eq("/") }
    it { URI.new(path: "/foo", query: "q=1").full_path.should eq("/foo?q=1") }
    it { URI.new(path: "/", query: "q=1").full_path.should eq("/?q=1") }
    it { URI.new(query: "q=1").full_path.should eq("/?q=1") }
    it { URI.new(path: "/a%3Ab").full_path.should eq("/a%3Ab") }

    it "does not add '?' to the end if the query params are empty" do
      uri = URI.parse("http://www.example.com/foo")
      uri.query = ""
      uri.full_path.should eq("/foo")
    end
  end

  describe "#absolute?" do
    it { URI.parse("http://www.example.com/foo").absolute?.should be_true }
    it { URI.parse("http://www.example.com").absolute?.should be_true }
    it { URI.parse("http://127.0.0.1").absolute?.should be_true }
    it { URI.parse("http://[::1]/").absolute?.should be_true }
    it { URI.parse("/foo").absolute?.should be_false }
    it { URI.parse("foo").absolute?.should be_false }
  end

  describe "#relative?" do
    it { URI.parse("/foo").relative?.should be_true }
  end

  describe "#normalize" do
    it "doesn't modify instance" do
      uri = URI.parse("HTTP://example.COM:80/./foo/../bar/")
      uri.normalize.should eq URI.parse("http://example.com/bar/")
      uri.should eq URI.parse("HTTP://example.COM:80/./foo/../bar/")
    end

    it "normalizes scheme" do
      URI.parse("HtTp://").normalize.should eq URI.parse("http://")
    end

    it "normalizes host" do
      URI.parse("http://FoO.cOm/").normalize.should eq URI.parse("http://foo.com/")
    end

    it "removes default port" do
      URI.new("http", "www.example.com", 80).normalize.to_s.should eq("http://www.example.com")
      URI.new("https", "www.example.com", 443).normalize.to_s.should eq("https://www.example.com")
      URI.new("ftp", "www.example.com", 21).normalize.to_s.should eq("ftp://www.example.com")
      URI.new("sftp", "www.example.com", 22).normalize.to_s.should eq("sftp://www.example.com")
      URI.new("ldap", "www.example.com", 389).normalize.to_s.should eq("ldap://www.example.com")
      URI.new("ldaps", "www.example.com", 636).normalize.to_s.should eq("ldaps://www.example.com")
    end

    it "removes dot notation from path" do
      URI.new(path: "../bar").normalize.path.should eq "bar"
      URI.new(path: "./bar").normalize.path.should eq "bar"
      URI.new(path: ".././bar").normalize.path.should eq "bar"
      URI.new(path: "/foo/./bar").normalize.path.should eq "/foo/bar"
      URI.new(path: "/bar/./").normalize.path.should eq "/bar/"
      URI.new(path: "/.").normalize.path.should eq "/"
      URI.new(path: "/bar/.").normalize.path.should eq "/bar/"
      URI.new(path: "/foo/../bar").normalize.path.should eq "/bar"
      URI.new(path: "/bar/../").normalize.path.should eq "/"
      URI.new(path: "/..").normalize.path.should eq "/"
      URI.new(path: "/bar/..").normalize.path.should eq "/"
      URI.new(path: "/foo/bar/..").normalize.path.should eq "/foo/"
      URI.new(path: ".").normalize.path.should eq ""
      URI.new(path: "..").normalize.path.should eq ""
    end

    it "prefixes relative path with colon with `./`" do
      URI.parse("./a:b").normalize.should eq URI.parse("./a:b")
      URI.parse("http:a:b").normalize.should eq URI.parse("http:./a:b")
    end
  end

  it "#normalize!" do
    uri = URI.parse("HTTP://example.COM:80/./foo/../bar/")
    uri.normalize!
    uri.should eq URI.parse("http://example.com/bar/")
  end

  it "implements ==" do
    URI.parse("http://example.com").should eq(URI.parse("http://example.com"))
  end

  it "implements hash" do
    URI.parse("http://example.com").hash.should eq(URI.parse("http://example.com").hash)
  end

  describe "userinfo" do
    it { URI.parse("http://www.example.com").userinfo.should be_nil }
    it { URI.parse("http://foo@www.example.com").userinfo.should eq("foo") }
    it { URI.parse("http://foo:bar@www.example.com").userinfo.should eq("foo:bar") }
  end

  describe "to_s" do
    it { URI.new("http", "www.example.com").to_s.should eq("http://www.example.com") }
    it { URI.new("http", "www.example.com", 80).to_s.should eq("http://www.example.com:80") }
    it { URI.new("http", "www.example.com", user: "alice").to_s.should eq("http://alice@www.example.com") }
    it { URI.new("http", "www.example.com", user: "alice", password: "s3cr3t").to_s.should eq("http://alice:s3cr3t@www.example.com") }
    it { URI.new("http", "www.example.com", user: ":D").to_s.should eq("http://%3AD@www.example.com") }
    it { URI.new("http", "www.example.com", user: ":D", password: "@_@").to_s.should eq("http://%3AD:%40_%40@www.example.com") }
    it { URI.new("http", "www.example.com", user: "@al:ce", password: "s/cr3t").to_s.should eq("http://%40al%3Ace:s%2Fcr3t@www.example.com") }
    it { URI.new("http", "www.example.com", fragment: "top").to_s.should eq("http://www.example.com#top") }
    it { URI.new("http", "www.example.com", 80, "/hello").to_s.should eq("http://www.example.com:80/hello") }
    it { URI.new("http", "www.example.com", 80, "/hello", "a=1").to_s.should eq("http://www.example.com:80/hello?a=1") }
    it { URI.new("mailto", path: "foo@example.com").to_s.should eq("mailto:foo@example.com") }
    it { URI.new("file", path: "/foo.html").to_s.should eq("file:/foo.html") }
    it { URI.new("file", path: "foo.html").to_s.should eq("file:foo.html") }
    it { URI.new("file", host: "host", path: "foo.html").to_s.should eq("file://host/foo.html") }
    it { URI.new(path: "//foo").to_s.should eq("/.//foo") }
    it { URI.new(host: "host", path: "//foo").to_s.should eq("//host//foo") }

    it "preserves non-default port" do
      URI.new("http", "www.example.com", 1234).to_s.should eq("http://www.example.com:1234")
      URI.new("https", "www.example.com", 1234).to_s.should eq("https://www.example.com:1234")
      URI.new("ftp", "www.example.com", 1234).to_s.should eq("ftp://www.example.com:1234")
      URI.new("sftp", "www.example.com", 1234).to_s.should eq("sftp://www.example.com:1234")
      URI.new("ldap", "www.example.com", 1234).to_s.should eq("ldap://www.example.com:1234")
      URI.new("ldaps", "www.example.com", 1234).to_s.should eq("ldaps://www.example.com:1234")
    end

    it "preserves port for unknown scheme" do
      URI.new("xyz", "www.example.com").to_s.should eq("xyz://www.example.com")
      URI.new("xyz", "www.example.com", 1234).to_s.should eq("xyz://www.example.com:1234")
    end

    it "preserves port for nil scheme" do
      URI.new(nil, "www.example.com", 1234).to_s.should eq("//www.example.com:1234")
    end
  end

  it "#opaque?" do
    URI.new.opaque?.should be_false
    URI.new("foo").opaque?.should be_true
    URI.new("foo", "example.com").opaque?.should be_false
    URI.new("foo", "").opaque?.should be_false
    URI.new("foo", path: "foo").opaque?.should be_true
    URI.new("foo", path: "/foo").opaque?.should be_false
  end

  describe ".default_port" do
    it "returns default port for well known schemes" do
      URI.default_port("http").should eq(80)
      URI.default_port("https").should eq(443)
    end

    it "returns nil for unknown schemes" do
      URI.default_port("xyz").should eq(nil)
    end

    it "treats scheme case insensitively" do
      URI.default_port("Http").should eq(80)
      URI.default_port("HTTP").should eq(80)
    end
  end

  describe ".set_default_port" do
    it "registers port for scheme" do
      URI.set_default_port("ponzi", 9999)
      URI.default_port("ponzi").should eq(9999)
    end

    it "unregisters port for scheme" do
      URI.set_default_port("ftp", nil)
      URI.default_port("ftp").should eq(nil)
    end

    it "treats scheme case insensitively" do
      URI.set_default_port("UNKNOWN", 1234)
      URI.default_port("unknown").should eq(1234)
    end
  end

  describe ".unescape" do
    {
      {"hello", "hello"},
      {"hello%20world", "hello world"},
      {"hello+world", "hello+world"},
      {"hello%", "hello%"},
      {"hello%2", "hello%2"},
      {"hello%2B", "hello+"},
      {"hello%2Bworld", "hello+world"},
      {"hello%2%2Bworld", "hello%2+world"},
      {"%E3%81%AA%E3%81%AA", "なな"},
      {"%e3%81%aa%e3%81%aa", "なな"},
      {"%27Stop%21%27+said+Fred", "'Stop!'+said+Fred"},
    }.each do |(from, to)|
      it "unescapes #{from}" do
        URI.unescape(from).should eq(to)
      end

      it "unescapes #{from} to IO" do
        String.build do |str|
          URI.unescape(from, str)
        end.should eq(to)
      end
    end

    it "unescapes plus to space" do
      URI.unescape("hello+world", plus_to_space: true).should eq("hello world")
      String.build do |str|
        URI.unescape("hello+world", str, plus_to_space: true)
      end.should eq("hello world")
    end

    it "does not unescape string when block returns true" do
      URI.unescape("hello%26world") { |byte| URI.reserved? byte }
        .should eq("hello%26world")
    end
  end

  describe ".escape" do
    [
      {"hello", "hello"},
      {"hello%20world", "hello world"},
      {"hello%25", "hello%"},
      {"hello%252", "hello%2"},
      {"hello%2B", "hello+"},
      {"hello%2Bworld", "hello+world"},
      {"hello%252%2Bworld", "hello%2+world"},
      {"%E3%81%AA%E3%81%AA", "なな"},
      {"%27Stop%21%27%20said%20Fred", "'Stop!' said Fred"},
      {"%0A", "\n"},
    ].each do |(from, to)|
      it "escapes #{to}" do
        URI.escape(to).should eq(from)
      end

      it "escapes #{to} to IO" do
        String.build do |str|
          URI.escape(to, str)
        end.should eq(from)
      end
    end

    describe "invalid utf8 strings" do
      input = String.new(1) { |buf| buf.value = 255_u8; {1, 0} }

      it "escapes without failing" do
        URI.escape(input).should eq("%FF")
      end

      it "escapes to IO without failing" do
        String.build do |str|
          URI.escape(input, str)
        end.should eq("%FF")
      end
    end

    it "escape space to plus when space_to_plus flag is true" do
      URI.escape("hello world", space_to_plus: true).should eq("hello+world")
      URI.escape("'Stop!' said Fred", space_to_plus: true).should eq("%27Stop%21%27+said+Fred")
    end

    it "does not escape character when block returns true" do
      URI.unescape("hello&world") { |byte| URI.reserved? byte }
        .should eq("hello&world")
    end
  end

  describe "reserved?" do
    reserved_chars = Set.new([':', '/', '?', '#', '[', ']', '@', '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '='])

    ('\u{00}'..'\u{7F}').each do |char|
      ok = reserved_chars.includes? char
      it "should return #{ok} on given #{char}" do
        URI.reserved?(char.ord.to_u8).should eq(ok)
      end
    end
  end

  describe "unreserved?" do
    unreserved_chars = Set.new(('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + ['_', '.', '-', '~'])

    ('\u{00}'..'\u{7F}').each do |char|
      ok = unreserved_chars.includes? char
      it "should return #{ok} on given #{char}" do
        URI.unreserved?(char.ord.to_u8).should eq(ok)
      end
    end
  end
end
