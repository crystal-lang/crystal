require "spec"
require "uri"

private def assert_uri(string, scheme = nil, host = nil, port = nil, path = "", query = nil, user = nil, password = nil, fragment = nil, opaque = nil)
  it "parse #{string}" do
    uri = URI.parse(string)
    uri.scheme.should eq(scheme)
    uri.host.should eq(host)
    uri.port.should eq(port)
    uri.path.should eq(path)
    uri.query.should eq(query)
    uri.user.should eq(user)
    uri.password.should eq(password)
    uri.fragment.should eq(fragment)
    uri.opaque.should eq(opaque)
  end
end

describe "URI" do
  assert_uri("http://www.example.com", scheme: "http", host: "www.example.com")
  assert_uri("http://www.example.com:81", scheme: "http", host: "www.example.com", port: 81)
  assert_uri("http://[::1]:81", scheme: "http", host: "[::1]", port: 81)
  assert_uri("http://www.example.com/foo", scheme: "http", host: "www.example.com", path: "/foo")
  assert_uri("http://www.example.com/foo?q=1", scheme: "http", host: "www.example.com", path: "/foo", query: "q=1")
  assert_uri("http://www.example.com?q=1", scheme: "http", host: "www.example.com", query: "q=1")
  assert_uri("https://www.example.com", scheme: "https", host: "www.example.com")
  assert_uri("https://alice:pa55w0rd@www.example.com", scheme: "https", host: "www.example.com", user: "alice", password: "pa55w0rd")
  assert_uri("https://alice@www.example.com", scheme: "https", host: "www.example.com", user: "alice", password: nil)
  assert_uri("https://%3AD:%40_%40@www.example.com", scheme: "https", host: "www.example.com", user: ":D", password: "@_@")
  assert_uri("https://www.example.com/#top", scheme: "https", host: "www.example.com", path: "/", fragment: "top")
  assert_uri("http://www.foo-bar.example.com", scheme: "http", host: "www.foo-bar.example.com")
  assert_uri("/foo", path: "/foo")
  assert_uri("/foo?q=1", path: "/foo", query: "q=1")
  assert_uri("mailto:foo@example.org", scheme: "mailto", path: nil, opaque: "foo@example.org")

  describe "hostname" do
    it { URI.parse("http://www.example.com/foo").hostname.should eq("www.example.com") }
    it { URI.parse("http://[::1]/foo").hostname.should eq("::1") }
    it { URI.parse("/foo").hostname.should be_nil }
  end

  describe "full_path" do
    it { URI.parse("http://www.example.com/foo").full_path.should eq("/foo") }
    it { URI.parse("http://www.example.com").full_path.should eq("/") }
    it { URI.parse("http://www.example.com/foo?q=1").full_path.should eq("/foo?q=1") }
    it { URI.parse("http://www.example.com/?q=1").full_path.should eq("/?q=1") }
    it { URI.parse("http://www.example.com?q=1").full_path.should eq("/?q=1") }
    it { URI.parse("http://test.dev/a%3Ab").full_path.should eq("/a%3Ab") }

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

  describe "normalize" do
    it "removes dot notation from path" do
      cases = {
        "../bar"      => "bar",
        "./bar"       => "bar",
        ".././bar"    => "bar",
        "/foo/./bar"  => "/foo/bar",
        "/bar/./"     => "/bar/",
        "/."          => "/",
        "/bar/."      => "/bar/",
        "/foo/../bar" => "/bar",
        "/bar/../"    => "/",
        "/.."         => "/",
        "/bar/.."     => "/",
        "/foo/bar/.." => "/foo/",
        "."           => "",
        ".."          => "",
      }

      cases.each do |input, expected|
        uri = URI.parse(input)
        uri = uri.normalize

        uri.path.should eq(expected), "failed to remove dot notation from #{input}"
      end
    end
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
    it { URI.new("http", "www.example.com", 80).to_s.should eq("http://www.example.com") }
    it do
      u = URI.new("http", "www.example.com")
      u.user = "alice"
      u.to_s.should eq("http://alice@www.example.com")
      u.password = "s3cr3t"
      u.to_s.should eq("http://alice:s3cr3t@www.example.com")
    end
    it do
      u = URI.new("http", "www.example.com")
      u.user = ":D"
      u.to_s.should eq("http://%3AD@www.example.com")
      u.password = "@_@"
      u.to_s.should eq("http://%3AD:%40_%40@www.example.com")
    end
    it { URI.new("http", "www.example.com", user: "@al:ce", password: "s/cr3t").to_s.should eq("http://%40al%3Ace:s%2Fcr3t@www.example.com") }
    it { URI.new("http", "www.example.com", fragment: "top").to_s.should eq("http://www.example.com#top") }
    it { URI.new("http", "www.example.com", 80, "/hello").to_s.should eq("http://www.example.com/hello") }
    it { URI.new("http", "www.example.com", 80, "/hello", "a=1").to_s.should eq("http://www.example.com/hello?a=1") }
    it { URI.new("mailto", opaque: "foo@example.com").to_s.should eq("mailto:foo@example.com") }

    it "removes default port" do
      URI.new("http", "www.example.com", 80).to_s.should eq("http://www.example.com")
      URI.new("https", "www.example.com", 443).to_s.should eq("https://www.example.com")
      URI.new("ftp", "www.example.com", 21).to_s.should eq("ftp://www.example.com")
      URI.new("sftp", "www.example.com", 22).to_s.should eq("sftp://www.example.com")
      URI.new("ldap", "www.example.com", 389).to_s.should eq("ldap://www.example.com")
      URI.new("ldaps", "www.example.com", 636).to_s.should eq("ldaps://www.example.com")
    end

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
      URI.new(nil, "www.example.com", 1234).to_s.should eq("www.example.com:1234")
    end
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
