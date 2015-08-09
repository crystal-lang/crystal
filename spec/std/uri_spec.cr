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
    assert { URI.new("http", "www.example.com", user: "@al:ce", password: "s/cr3t").to_s.should eq("http://%40al%3Ace:s%2Fcr3t@www.example.com") }
    assert { URI.new("http", "www.example.com", fragment: "top").to_s.should eq("http://www.example.com#top") }
    assert { URI.new("http", "www.example.com", 1234).to_s.should eq("http://www.example.com:1234") }
    assert { URI.new("http", "www.example.com", 80, "/hello").to_s.should eq("http://www.example.com/hello") }
    assert { URI.new("http", "www.example.com", 80, "/hello", "a=1").to_s.should eq("http://www.example.com/hello?a=1") }
    assert { URI.new("mailto", opaque: "foo@example.com").to_s.should eq("mailto:foo@example.com") }
  end
end

