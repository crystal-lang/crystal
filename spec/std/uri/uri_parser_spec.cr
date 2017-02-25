require "spec"
require "uri"

# Some specs are commented for now because struct inheritance is no longer
# supported, we have to figure out a way to make this testeable again.

# struct URI::TestParser < URI::Parser
#   property ptr

#   macro step(method)
#     return :{{method}}
#   end
# end

# struct URI::VerboseParser < URI::Parser
#   macro step(method)
#     puts "moving to {{method}} at #{@ptr}: #{c.chr}"
#     return {{method}}
#   end
# end

# def test_parser(url = "", ptr = 0)
#   par = URI::TestParser.new(url)
#   par.ptr = ptr
#   par
# end

# private macro test(parser_meth, url, start_ptr, end_ptr, next_meth, uri_meth = nil, expected = nil, file = __FILE__, line = __LINE__)
#   it "{{parser_meth}} on \"#{{{url}}}\"", {{file}}, {{line}} do
#     par = test_parser(url: {{url}}, ptr: {{start_ptr}})
#     par.{{parser_meth}}.should eq({{next_meth}})
#     par.ptr.should eq({{end_ptr}})
#     {% if uri_meth %}
#       par.uri.{{uri_meth}}.should eq({{expected}})
#     {% end %}
#   end
# end

# describe URI::Parser, "steps" do
#   test parse_scheme_start,
#     "aurl", 0, 0,
#     :parse_scheme

#   test parse_scheme_start,
#     "1", 0, 0,
#     :parse_no_scheme

#   test parse_scheme,
#     "my-thing+yes.2://", 0, 16,
#     :parse_path_or_authority,
#     scheme, "my-thing+yes.2"

#   test parse_scheme,
#     "mailto:foo", 0, 6,
#     :nil,
#     scheme, "mailto"

#   test parse_scheme,
#     "mailto:foo", 0, 6,
#     :nil,
#     opaque, "foo"

#   test parse_scheme,
#     "/path/absolute/url", 0, 0,
#     :parse_no_scheme,
#     scheme, nil

#   test parse_path_or_authority,
#     "http://bitfission.com", 6, 6,
#     :parse_authority

#   test parse_path_or_authority,
#     "test:/path", 6, 5,
#     :parse_path

#   test parse_no_scheme,
#     "#justfragment", 0, 0,
#     :parse_fragment

#   test parse_no_scheme,
#     "/justpath", 0, 0,
#     :parse_relative

#   test parse_authority,
#     "http://bitfission.com", 6, 7,
#     :parse_host

#   test parse_authority,
#     "http://user@bitfission.com", 6, 7,
#     :parse_userinfo

#   test parse_authority,
#     "http://user:pass@bitfission.com", 6, 7,
#     :parse_userinfo

#   test parse_userinfo,
#     "http://%3Auser@bitfission.com", 7, 15,
#     :parse_host,
#     user, ":user"

#   test parse_userinfo,
#     "http://%3Auser:pass@bitfission.com", 7, 20,
#     :parse_host,
#     user, ":user"

#   test parse_userinfo,
#     "http://user:%3Apass@bitfission.com", 7, 20,
#     :parse_host,
#     password, ":pass"

#   test parse_host,
#     "http://bitfission.com", 7, 21,
#     :parse_path,
#     host, "bitfission.com"

#   test parse_host,
#     "http://bitfission.com/", 7, 21,
#     :parse_path,
#     host, "bitfission.com"

#   test parse_host,
#     "http://bitfission.com:8080/", 7, 22,
#     :parse_port,
#     host, "bitfission.com"

#   test parse_host,
#     "http://bitfission.com/something", 7, 21,
#     :parse_path,
#     host, "bitfission.com"

#   test parse_host,
#     "http://bitfission.com?foo=bar", 7, 21,
#     :parse_path,
#     host, "bitfission.com"

#   test parse_host,
#     "http://bitfission.com#anchor", 7, 21,
#     :parse_path,
#     host, "bitfission.com"

#   test parse_host,
#     "http://[::1]", 7, 12,
#     :parse_path,
#     host, "[::1]"

#   test parse_host,
#     "file:///no/host", 7, 7,
#     :parse_path,
#     host, nil

#   test parse_port,
#     "http://a.com:8080", 13, 17,
#     :parse_path,
#     port, 8080

#   test parse_relative,
#     "", 0, 0,
#     :nil

#   test parse_relative,
#     "/path", 0, 0,
#     :parse_relative_slash

#   test parse_relative,
#     "?query", 0, 0,
#     :parse_query

#   test parse_relative,
#     "?query", 0, 0,
#     :parse_query

#   test parse_relative_slash,
#     "//bitfission.com", 0, 1,
#     :parse_authority

#   test parse_relative_slash,
#     "/a/path", 0, 0,
#     :parse_path

#   test parse_path,
#     "/somepath", 0, 9,
#     :nil,
#     path, "/somepath"

#   test parse_path,
#     "/somepath?foo=yes", 0, 9,
#     :parse_query,
#     path, "/somepath"

#   test parse_path,
#     "/somepath#foo", 0, 9,
#     :parse_fragment,
#     path, "/somepath"

#   test parse_query,
#     "?a=b&c=d", 0, 8,
#     :nil,
#     query, "a=b&c=d"

#   test parse_query,
#     "?a=b&c=d#frag", 0, 8,
#     :parse_fragment,
#     query, "a=b&c=d"

#   test parse_fragment,
#     "#frag", 0, 5,
#     :nil,
#     fragment, "frag"
# end

describe URI::Parser, "#run" do
  it "runs for normal urls" do
    uri = URI::Parser.new("http://user:pass@bitfission.com:8080/path?a=b#frag").run.uri
    uri.scheme.should eq("http")
    uri.user.should eq("user")
    uri.password.should eq("pass")
    uri.host.should eq("bitfission.com")
    uri.port.should eq(8080)
    uri.path.should eq("/path")
    uri.query.should eq("a=b")
    uri.fragment.should eq("frag")
  end

  it "runs for schemelss urls" do
    uri = URI::Parser.new("//user:pass@bitfission.com:8080/path?a=b#frag").run.uri
    uri.scheme.should eq(nil)
    uri.user.should eq("user")
    uri.password.should eq("pass")
    uri.host.should eq("bitfission.com")
    uri.port.should eq(8080)
    uri.path.should eq("/path")
    uri.query.should eq("a=b")
    uri.fragment.should eq("frag")
  end

  it "runs for path relative urls" do
    uri = URI::Parser.new("/path?a=b#frag").run.uri
    uri.scheme.should eq(nil)
    uri.host.should eq(nil)
    uri.path.should eq("/path")
    uri.query.should eq("a=b")
    uri.fragment.should eq("frag")
  end

  it "runs for path mailto" do
    uri = URI::Parser.new("mailto:user@example.com").run.uri
    uri.scheme.should eq("mailto")
    uri.opaque.should eq("user@example.com")
  end

  it "runs for file wth and without host" do
    uri = URI::Parser.new("file://localhost/etc/fstab").run.uri
    uri.scheme.should eq("file")
    uri.host.should eq("localhost")
    uri.path.should eq("/etc/fstab")

    uri = URI::Parser.new("file:///etc/fstab").run.uri
    uri.scheme.should eq("file")
    uri.host.should eq(nil)
    uri.path.should eq("/etc/fstab")
  end

  it "runs for scheme and path only urls" do
    uri = URI::Parser.new("test:/test").run.uri
    uri.scheme.should eq("test")
    uri.path.should eq("/test")
  end

  context "bad urls" do
    it { expect_raises(URI::Error) { URI::Parser.new("http://some.com:8f80/path").run } }
  end
end
