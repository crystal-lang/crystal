require "spec"
require "cgi"

describe "CGI" do
  [
    { "foo=bar", {"foo" => ["bar"]} },
    { "foo=bar&foo=baz", {"foo" => ["bar", "baz"]} },
    { "foo=bar&baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
    { "foo=bar;baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
    { "foo=hello%2Bworld", {"foo" => ["hello+world"]} },
    { "foo=", {"foo" => [""]} },
    { "foo", {"foo" => [""]} },
    { "foo=&bar", { "foo" => [""], "bar" => [""] } },
    { "bar&foo", { "bar" => [""], "foo" => [""] } },
  ].each do |tuple|
    from, to = tuple
    it "parses #{from}" do
      CGI.parse(from).should eq(to)
    end
  end
end
