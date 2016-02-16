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

  assert { URI.parse("http://www.example.com/foo").full_path.should eq("/foo") }
  assert { URI.parse("http://www.example.com").full_path.should eq("/") }
  assert { URI.parse("http://www.example.com/foo?q=1").full_path.should eq("/foo?q=1") }
  assert { URI.parse("http://www.example.com/?q=1").full_path.should eq("/?q=1") }
  assert { URI.parse("http://www.example.com?q=1").full_path.should eq("/?q=1") }
  assert { URI.parse("http://test.dev/a%3Ab").full_path.should eq("/a%3Ab") }

  describe "userinfo" do
    assert { URI.parse("http://www.example.com").userinfo.should be_nil }
    assert { URI.parse("http://foo@www.example.com").userinfo.should eq("foo") }
    assert { URI.parse("http://foo:bar@www.example.com").userinfo.should eq("foo:bar") }
  end

  describe "to_s" do
    assert { URI.new("http", "www.example.com").to_s.should eq("http://www.example.com") }
    assert { URI.new("http", "www.example.com", 80).to_s.should eq("http://www.example.com") }
    assert do
      u = URI.new("http", "www.example.com")
      u.user = "alice"
      u.to_s.should eq("http://alice@www.example.com")
      u.password = "s3cr3t"
      u.to_s.should eq("http://alice:s3cr3t@www.example.com")
    end
    assert do
      u = URI.new("http", "www.example.com")
      u.user = ":D"
      u.to_s.should eq("http://%3AD@www.example.com")
      u.password = "@_@"
      u.to_s.should eq("http://%3AD:%40_%40@www.example.com")
    end
    assert { URI.new("http", "www.example.com", user: "@al:ce", password: "s/cr3t").to_s.should eq("http://%40al%3Ace:s%2Fcr3t@www.example.com") }
    assert { URI.new("http", "www.example.com", fragment: "top").to_s.should eq("http://www.example.com#top") }
    assert { URI.new("http", "www.example.com", 1234).to_s.should eq("http://www.example.com:1234") }
    assert { URI.new("http", "www.example.com", 80, "/hello").to_s.should eq("http://www.example.com/hello") }
    assert { URI.new("http", "www.example.com", 80, "/hello", "a=1").to_s.should eq("http://www.example.com/hello?a=1") }
    assert { URI.new("mailto", opaque: "foo@example.com").to_s.should eq("mailto:foo@example.com") }
  end

  describe ".unescape" do
    {
      {"hello", "hello"},
      {"hello+world", "hello world"},
      {"hello%20world", "hello world"},
      {"hello%", "hello%"},
      {"hello%2", "hello%2"},
      {"hello%2B", "hello+"},
      {"hello%2Bworld", "hello+world"},
      {"hello%2%2Bworld", "hello%2+world"},
      {"%E3%81%AA%E3%81%AA", "なな"},
      {"%e3%81%aa%e3%81%aa", "なな"},
      {"%27Stop%21%27+said+Fred", "'Stop!' said Fred"},
    }.each do |tuple|
      from, to = tuple

      it "unescapes #{from}" do
        URI.unescape(from).should eq(to)
      end

      it "unescapes #{from} to IO" do
        String.build do |str|
          URI.unescape(from, str)
        end.should eq(to)
      end
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
      {"%FF", String.new(1) { |buf| buf.value = 255_u8; {1, 0} }},
      {"%0A", "\n"},
    ].each do |tuple|
      from, to = tuple
      it "escapes #{to}" do
        URI.escape(to).should eq(from)
      end

      it "escapes #{to} to IO" do
        String.build do |str|
          URI.escape(to, str)
        end.should eq(from)
      end
    end
  end
end
