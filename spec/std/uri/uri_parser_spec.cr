require "spec"
require "../../../src/uri/uri_parser"

class TestParser < URIParser
  property ptr
  macro cor(method)
    return :{{method}}
  end
end

describe URIParser, "scheme_start" do
  it "goes to parse_scheme if first char is alpha" do
    par = TestParser.new("h")
    par.parse_scheme_start.should eq(:parse_scheme)

    par = TestParser.new("1")
    par.parse_scheme_start.should_not eq(:parse_scheme)
  end
end

describe URIParser, "parse_scheme" do
  it "puts (alpha - + .) up to : into uri's scheme" do
    par = TestParser.new("my-thing+yes.a://")
    par.parse_scheme.should eq(:parse_path_or_authority)
    par.uri.scheme.should eq("my-thing+yes.a")
    par.ptr.should eq(15)
  end
end

describe URIParser, "parse_path_or_authority" do
  it "advances the pointer 1 and goes to authority if at /" do
    par = TestParser.new("http://bitfission.com")
    par.ptr = 5
    par.parse_path_or_authority.should eq(:parse_authority)
    par.ptr.should eq(6)
  end
end

describe URIParser, "#run" do
  it "runs all appropriate steps" do
    par = URIParser.new("http://bitfission.com")
    par.run
    par.uri.scheme.should eq("http")
    par.uri.host.should eq("bitfission.com")
  end
end
