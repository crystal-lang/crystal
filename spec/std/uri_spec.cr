require "spec"
require "uri"

private def assert_uri(string, file = __FILE__, line = __LINE__, **args)
  it "`#{string}`", file, line do
    URI.parse(string).should eq URI.new(**args)
    URI.parse(string).to_s.should eq string
  end
end

private def it_encodes(string, expected_result, file = __FILE__, line = __LINE__, **options)
  it "encodes #{string.inspect}", file, line do
    URI.encode(string, **options).should eq(expected_result), file, line

    String.build do |io|
      URI.encode(string, io, **options)
    end.should eq(expected_result), file, line
  end
end

private def it_decodes(string, expected_result, file = __FILE__, line = __LINE__, **options)
  it "decodes #{string.inspect}", file, line do
    URI.decode(string, **options).should eq(expected_result), file, line

    String.build do |io|
      URI.decode(string, io, **options)
    end.should eq(expected_result), file, line
  end
end

private def it_encodes_www_form(string, expected_result, file = __FILE__, line = __LINE__, **options)
  it "encodes #{string.inspect}", file, line do
    URI.encode_www_form(string, **options).should eq(expected_result), file, line

    String.build do |io|
      URI.encode_www_form(string, io, **options)
    end.should eq(expected_result), file, line
  end
end

private def it_decodes_www_form(string, expected_result, file = __FILE__, line = __LINE__, **options)
  it "decodes #{string.inspect}", file, line do
    URI.decode_www_form(string, **options).should eq(expected_result), file, line

    String.build do |io|
      URI.decode_www_form(string, io, **options)
    end.should eq(expected_result), file, line
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
    it { URI.new(user: "ä /", password: "ö :").userinfo.should eq("%C3%A4+%2F:%C3%B6+%3A") }
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

  describe ".decode" do
    it_decodes("hello", "hello")
    it_decodes("hello%20world", "hello world")
    it_decodes("hello+world", "hello+world")
    it_decodes("hello%", "hello%")
    it_decodes("hello%2", "hello%2")
    it_decodes("hello%2B", "hello+")
    it_decodes("hello%2Bworld", "hello+world")
    it_decodes("hello%2%2Bworld", "hello%2+world")
    it_decodes("%E3%81%AA%E3%81%AA", "なな")
    it_decodes("%e3%81%aa%e3%81%aa", "なな")
    it_decodes("%27Stop%21%27+said+Fred", "'Stop!'+said+Fred")
    it_decodes("hello+world", "hello world", plus_to_space: true)
    it_decodes("+%2B %20", "++  ")

    it "does not decode string when block returns true" do
      String.build do |io|
        URI.decode("hello%26world", io) { |byte| URI.reserved? byte }
      end.should eq("hello%26world")
    end
  end

  describe ".encode" do
    it_encodes("hello", "hello")
    it_encodes("hello world", "hello%20world")
    it_encodes("hello%", "hello%25")
    it_encodes("hello%2", "hello%252")
    it_encodes("hello+", "hello+")
    it_encodes("hello+world", "hello+world")
    it_encodes("hello%2+world", "hello%252+world")
    it_encodes("なな", "%E3%81%AA%E3%81%AA")
    it_encodes("'Stop!' said Fred", "'Stop!'%20said%20Fred")
    it_encodes("\n", "%0A")
    it_encodes("https://en.wikipedia.org/wiki/Crystal (programming language)", "https://en.wikipedia.org/wiki/Crystal%20(programming%20language)")
    it_encodes("\xFF", "%FF") # encodes invalid UTF-8 character
    it_encodes("hello world", "hello+world", space_to_plus: true)
    it_encodes("'Stop!' said Fred", "'Stop!'+said+Fred", space_to_plus: true)

    it "does not encode character when block returns true" do
      String.build do |io|
        URI.decode("hello&world", io) { |byte| URI.reserved? byte }
      end.should eq("hello&world")
    end
  end

  describe ".encode_www_form" do
    it_encodes_www_form("", "")
    it_encodes_www_form("abc", "abc")
    it_encodes_www_form("1%41", "1%2541")
    it_encodes_www_form("a b+", "a+b%2B")
    it_encodes_www_form("a b+", "a%20b%2B", space_to_plus: false)
    it_encodes_www_form("10%", "10%25")
    it_encodes_www_form(" ?&=#+%!<>#\"{}|\\^[]`☺\t:/@$'()*,;", "+%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09%3A%2F%40%24%27%28%29%2A%2C%3B")
    it_encodes_www_form("* foo=bar baz&hello/", "%2A+foo%3Dbar+baz%26hello%2F")
  end

  describe ".decode_www_form" do
    it_decodes_www_form("", "")
    it_decodes_www_form("abc", "abc")
    it_decodes_www_form("1%41", "1A")
    it_decodes_www_form("1%41%42%43", "1ABC")
    it_decodes_www_form("%4a", "J")
    it_encodes_www_form("hello+", "hello%2B")
    it_encodes_www_form("hello+world", "hello%2Bworld")
    it_encodes_www_form("hello%2+world", "hello%252%2Bworld")
    it_encodes_www_form("'Stop!' said Fred", "%27Stop%21%27+said+Fred")
    it_decodes_www_form("a+b", "a b")
    it_decodes_www_form("a%20b", "a b")
    it_decodes_www_form("%20%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09%3A%2F%40%24%27%28%29%2A%2C%3B", " ?&=#+%!<>#\"{}|\\^[]`☺\t:/@$'()*,;")
    it_decodes_www_form("+%2B %20", " +  ")

    it_decodes_www_form("%", "%")
    it_decodes_www_form("%1", "%1")
    it_decodes_www_form("123%45%6", "123E%6")
    it_decodes_www_form("%zzzzz", "%zzzzz")
  end

  it ".reserved?" do
    reserved_chars = Set{':', '/', '?', '#', '[', ']', '@', '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '='}

    ('\u{00}'..'\u{7F}').each do |char|
      URI.reserved?(char.ord.to_u8).should eq(reserved_chars.includes?(char))
    end
  end

  it ".unreserved?" do
    unreserved_chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + ['_', '.', '-', '~']

    ('\u{00}'..'\u{7F}').each do |char|
      URI.unreserved?(char.ord.to_u8).should eq(unreserved_chars.includes?(char))
    end
  end
end
