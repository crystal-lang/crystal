#!/usr/bin/env bin/crystal --run
require "spec"
require "uri"

def assert_uri(string, scheme, host, port, path, query_string)
  it "parse #{string}" do
    uri = URI.parse(string)
    uri.scheme.should eq(scheme)
    uri.host.should eq(host)
    uri.port.should eq(port)
    uri.path.should eq(path)
    uri.query_string.should eq(query_string)
  end
end

describe "URI" do
  assert_uri("http://www.google.com", "http", "www.google.com", nil, nil, nil)
  assert_uri("http://www.google.com:81", "http", "www.google.com", 81, nil, nil)
  assert_uri("http://www.google.com/foo", "http", "www.google.com", nil, "/foo", nil)
  assert_uri("http://www.google.com/foo?q=1", "http", "www.google.com", nil, "/foo", "q=1")
  assert_uri("http://www.google.com?q=1", "http", "www.google.com", nil, nil, "q=1")
  assert_uri("https://www.google.com", "https", "www.google.com", nil, nil, nil)
  assert_uri("http://www.foo-bar.com", "http", "www.foo-bar.com", nil, nil, nil)
  assert_uri("/foo", nil, nil, nil, "/foo", nil)
  assert_uri("/foo?q=1", nil, nil, nil, "/foo", "q=1")

  assert { URI.parse("http://www.google.com/foo").full_path.should eq("/foo") }
  assert { URI.parse("http://www.google.com").full_path.should eq("/") }
  assert { URI.parse("http://www.google.com/foo?q=1").full_path.should eq("/foo?q=1") }
  assert { URI.parse("http://www.google.com/?q=1").full_path.should eq("/?q=1") }
  assert { URI.parse("http://www.google.com?q=1").full_path.should eq("/?q=1") }
end

