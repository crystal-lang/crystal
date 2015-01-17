require "spec"
require "uri"

private def assert_uri(string, scheme = nil, host = nil, port = nil, path = nil, query = nil)
  it "parse #{string}" do
    uri = URI.parse(string)
    uri.scheme.should eq(scheme)
    uri.host.should eq(host)
    uri.port.should eq(port)
    uri.path.should eq(path)
    uri.query.should eq(query)
  end
end

describe "URI" do
  assert_uri("http://www.google.com", scheme: "http", host: "www.google.com")
  assert_uri("http://www.google.com:81", scheme: "http", host: "www.google.com", port: 81)
  assert_uri("http://www.google.com/foo", scheme: "http", host: "www.google.com", path: "/foo")
  assert_uri("http://www.google.com/foo?q=1", scheme: "http", host: "www.google.com", path: "/foo", query: "q=1")
  assert_uri("http://www.google.com?q=1", scheme: "http", host: "www.google.com", query: "q=1")
  assert_uri("https://www.google.com", scheme: "https", host: "www.google.com")
  assert_uri("http://www.foo-bar.com", scheme: "http", host: "www.foo-bar.com")
  assert_uri("/foo", path: "/foo")
  assert_uri("/foo?q=1", path: "/foo", query: "q=1")

  assert { URI.parse("http://www.google.com/foo").full_path.should eq("/foo") }
  assert { URI.parse("http://www.google.com").full_path.should eq("/") }
  assert { URI.parse("http://www.google.com/foo?q=1").full_path.should eq("/foo?q=1") }
  assert { URI.parse("http://www.google.com/?q=1").full_path.should eq("/?q=1") }
  assert { URI.parse("http://www.google.com?q=1").full_path.should eq("/?q=1") }

  describe "to_s" do
    assert { URI.new("http", "www.google.com").to_s.should eq("http://www.google.com") }
    assert { URI.new("http", "www.google.com", 80).to_s.should eq("http://www.google.com") }
    assert { URI.new("http", "www.google.com", 1234).to_s.should eq("http://www.google.com:1234") }
    assert { URI.new("http", "www.google.com", 80, "/hello").to_s.should eq("http://www.google.com/hello") }
    assert { URI.new("http", "www.google.com", 80, "/hello", "a=1").to_s.should eq("http://www.google.com/hello?a=1") }
  end
end

