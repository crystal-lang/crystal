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

describe URIParser, "parse_scheme_start" do
  it "goes to parse_scheme if first char is alpha" do
    par = TestParser.new("h")
    par.parse_scheme_start.should eq(:parse_scheme)

    par = TestParser.new("1")
    par.parse_scheme_start.should_not eq(:parse_scheme)
  end
end

describe URIParser, "parse_scheme" do
  it "puts (alpha - + .) up to : into uri's scheme" do
    par = TestParser.new("my-thing+yes.2://")
    par.parse_scheme.should eq(:parse_path_or_authority)
    par.uri.scheme.should eq("my-thing+yes.2")
    par.ptr.should eq(15)
  end
end

describe URIParser, "parse_path_or_authority" do
  it "advances the pointer 1 and goes to authority if at /" do
    par = test_parser(url: "http://bitfission.com", ptr: 5)
    par.parse_path_or_authority.should eq(:parse_authority)
    par.ptr.should eq(6)
  end
end

describe URIParser, "parse_authority" do
  it "advances the pointer 1 and goes to host" do
    par = test_parser(url: "http://bitfission.com", ptr: 6)
    par.parse_authority.should eq(:parse_host)
    par.ptr.should eq(7)
  end
end

describe URIParser, "parse_host" do
  it "puts the host into uri" do
    par = test_parser(url: "http://bitfission.com", ptr: 7)
    par.parse_host.should eq(:parse_path)
    par.ptr.should eq(21)
    par.uri.host.should eq("bitfission.com")
  end

  it "can handle different endings" do
    %w(/ ? \ #).each do |ending|
      par = test_parser(url: "http://bitfission.com#{ending}", ptr: 7)
      par.uri.scheme = "http"
      par.parse_host
      par.uri.host.should eq("bitfission.com")
    end
  end

  it "allows : inside [] for ipv6" do
    par = test_parser(url: "http://[::1]/", ptr: 7)
    par.parse_host
    par.uri.host.should eq("[::1]")
  end
end

describe URIParser, "parse_port" do
  it "puts the port into the uri" do
    par = test_parser(url: "http://a.com:8080", ptr: 13)
    par.parse_port.should eq(:parse_path)
    par.ptr.should eq(17)
    par.uri.port.should eq(8080)
  end
end

describe URIParser, "parse_path" do
  it "puts the port into the uri" do
    par = test_parser(url: "/somepath?foo=yes", ptr: 0)
    par.parse_path.should eq(:nil)
    par.ptr.should eq(9)
    par.uri.path.should eq("/somepath")
  end
end

describe URIParser, "#run" do
  it "runs all appropriate steps" do
    par = URIParser.new("http://bitfission.com/path")
    par.run
    par.uri.scheme.should eq("http")
    par.uri.host.should eq("bitfission.com")
    par.uri.path.should eq("/path")
  end
end
