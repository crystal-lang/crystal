require "spec"
require "cgi"

describe "CGI" do
  [
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
  ].each do |tuple|
    from, to = tuple
    it "unescapes #{from}" do
      expect(CGI.unescape(from)).to eq(to)
    end

    it "unescapes #{from} to IO" do
      expect(String.build do |str|
        CGI.unescape(from, str)
      end).to eq(to)
    end
  end

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
  ].each do |tuple|
    from, to = tuple
    it "escapes #{to}" do
      expect(CGI.escape(to)).to eq(from)
    end

    it "escapes #{to} to IO" do
      expect(String.build do |str|
        CGI.escape(to, str)
      end).to eq(from)
    end
  end

  [
    { "foo=bar", {"foo" => ["bar"]} },
    { "foo=bar&foo=baz", {"foo" => ["bar", "baz"]} },
    { "foo=bar&baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
    { "foo=bar;baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
    { "foo=hello%2Bworld", {"foo" => ["hello+world"]} },
    { "foo=", {"foo" => [""]} },
    { "foo", {"foo" => [""]} },
  ].each do |tuple|
    from, to = tuple
    it "parses #{from}" do
      expect(CGI.parse(from)).to eq(to)
    end
  end

  it "escapes newline char" do
    expect(CGI.escape("\n")).to eq("%0A")
  end
end
