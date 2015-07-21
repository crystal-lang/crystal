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
  assert_uri("http://www.google.com", scheme: "http", host: "www.google.com")
  assert_uri("http://www.google.com:81", scheme: "http", host: "www.google.com", port: 81)
  assert_uri("http://www.google.com/foo", scheme: "http", host: "www.google.com", path: "/foo")
  assert_uri("http://www.google.com/foo?q=1", scheme: "http", host: "www.google.com", path: "/foo", query: "q=1")
  assert_uri("http://www.google.com?q=1", scheme: "http", host: "www.google.com", query: "q=1")
  assert_uri("https://www.google.com", scheme: "https", host: "www.google.com")
  assert_uri("https://alice:pa55w0rd@www.google.com", scheme: "https", host: "www.google.com", user: "alice", password: "pa55w0rd")
  assert_uri("https://alice@www.google.com", scheme: "https", host: "www.google.com", user: "alice", password: nil)
  assert_uri("https://www.google.com/#top", scheme: "https", host: "www.google.com", path: "/", fragment: "top")
  assert_uri("http://www.foo-bar.com", scheme: "http", host: "www.foo-bar.com")
  assert_uri("/foo", path: "/foo")
  assert_uri("/foo?q=1", path: "/foo", query: "q=1")
  assert_uri("mailto:foo@example.org", scheme: "mailto", path: nil, opaque: "foo@example.org")

  assert { URI.parse("http://www.google.com/foo").full_path.should eq("/foo") }
  assert { URI.parse("http://www.google.com").full_path.should eq("/") }
  assert { URI.parse("http://www.google.com/foo?q=1").full_path.should eq("/foo?q=1") }
  assert { URI.parse("http://www.google.com/?q=1").full_path.should eq("/?q=1") }
  assert { URI.parse("http://www.google.com?q=1").full_path.should eq("/?q=1") }

  describe "userinfo" do
    assert { URI.parse("http://www.google.com").userinfo.should be_nil }
    assert { URI.parse("http://foo@www.google.com").userinfo.should eq("foo") }
    assert { URI.parse("http://foo:bar@www.google.com").userinfo.should eq("foo:bar") }
  end

  describe "to_s" do
    assert { URI.new("http", "www.google.com").to_s.should eq("http://www.google.com") }
    assert { URI.new("http", "www.google.com", 80).to_s.should eq("http://www.google.com") }
    assert do
      u = URI.new("http", "www.google.com")
      u.user = "alice"
      u.to_s.should eq("http://alice@www.google.com")
      u.password = "s3cr3t"
      u.to_s.should eq("http://alice:s3cr3t@www.google.com")
    end
    assert { URI.new("http", "www.google.com", user: "@al:ce", password: "s/cr3t").to_s.should eq("http://%40al%3Ace:s%2Fcr3t@www.google.com") }
    assert { URI.new("http", "www.google.com", fragment: "top").to_s.should eq("http://www.google.com#top") }
    assert { URI.new("http", "www.google.com", 1234).to_s.should eq("http://www.google.com:1234") }
    assert { URI.new("http", "www.google.com", 80, "/hello").to_s.should eq("http://www.google.com/hello") }
    assert { URI.new("http", "www.google.com", 80, "/hello", "a=1").to_s.should eq("http://www.google.com/hello?a=1") }
    assert { URI.new("mailto", opaque: "foo@example.com").to_s.should eq("mailto:foo@example.com") }
  end
end

