require "spec"
require "../../../src/uri/uri_parser"

class TestParser < URIParser
  property ptr

  macro cor(method)
    return :{{method}}
  end
end

def test_parser(url = "", ptr = 0)
  par = TestParser.new(url)
  par.ptr = ptr
  par
end

private macro test(parser_meth, url, start_ptr, end_ptr, next_meth, uri_meth = nil, expected = nil, file = __FILE__, line = __LINE__)
  it "{{parser_meth}} on \"#{{{url}}}\"", {{file}}, {{line}} do
    par = test_parser(url: {{url}}, ptr: {{start_ptr}})
    par.{{parser_meth}}.should eq({{next_meth}})
    par.ptr.should eq({{end_ptr}})
    {% if uri_meth %}
      par.uri.{{uri_meth}}.should eq({{expected}})
    {% end %}
  end
end

describe URIParser, "steps" do
  test parse_scheme_start,
    "aurl", 0, 0,
    :parse_scheme

  test parse_scheme_start,
    "1", 0, 0,
    :nil

  test parse_scheme,
    "my-thing+yes.2://", 0, 15,
    :parse_path_or_authority,
    scheme, "my-thing+yes.2"

  test parse_path_or_authority,
    "http://bitfission.com", 5, 6,
    :parse_authority

  test parse_authority,
    "http://bitfission.com", 6, 7,
    :parse_host

  test parse_host,
    "http://bitfission.com", 7, 21,
    :parse_path,
    host, "bitfission.com"

  test parse_host,
    "http://bitfission.com/something", 7, 21,
    :parse_path,
    host, "bitfission.com"

  test parse_host,
    "http://bitfission.com?foo=bar", 7, 21,
    :parse_path,
    host, "bitfission.com"

  test parse_host,
    "http://bitfission.com#anchor", 7, 21,
    :parse_path,
    host, "bitfission.com"

  test parse_host,
    "http://[::1]", 7, 12,
    :parse_path,
    host, "[::1]"

  test parse_port,
    "http://a.com:8080", 13, 17,
    :parse_path,
    port, 8080

  test parse_path,
    "/somepath", 0, 9,
    :nil,
    path, "/somepath"

  test parse_path,
    "/somepath?foo=yes", 0, 9,
    :parse_query,
    path, "/somepath"

  test parse_path,
    "/somepath#foo", 0, 9,
    :parse_fragment,
    path, "/somepath"

  test parse_query,
    "?a=b&c=d", 0, 8,
    :nil,
    query, "?a=b&c=d"

  test parse_query,
    "?a=b&c=d#frag", 0, 8,
    :parse_fragment,
    query, "?a=b&c=d"

  test parse_fragment,
    "#frag", 0, 5,
    :nil,
    fragment, "#frag"
end

describe URIParser, "#run" do
  it "runs all appropriate steps" do
    par = URIParser.new("http://bitfission.com/path?a=b#frag")
    par.run
    par.uri.scheme.should eq("http")
    par.uri.host.should eq("bitfission.com")
    par.uri.path.should eq("/path")
    par.uri.query.should eq("?a=b")
    par.uri.fragment.should eq("#frag")
  end
end
