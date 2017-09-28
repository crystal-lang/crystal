require "spec"
require "http/headers"

describe HTTP::Headers do
  it "is empty" do
    headers = HTTP::Headers.new
    headers.empty?.should be_true
  end

  it "is case insensitive" do
    headers = HTTP::Headers{"Foo" => "bar"}
    headers["foo"].should eq("bar")
  end

  it "it allows indifferent access for underscore and dash separated keys" do
    headers = HTTP::Headers{"foo_Bar" => "bar", "Foobar-foo" => "baz"}
    headers["foo-bar"].should eq("bar")
    headers["foobar_foo"].should eq("baz")
  end

  it "raises an error if header value contains invalid character" do
    expect_raises ArgumentError do
      headers = HTTP::Headers{"invalid-header" => "\r\nLocation: http://example.com"}
    end
  end

  it "should retain the input casing" do
    headers = HTTP::Headers{"FOO_BAR" => "bar", "Foobar-foo" => "baz"}
    serialized = String.build do |io|
      headers.each do |name, values|
        io << name << ": " << values.first << ";"
      end
    end

    serialized.should eq("FOO_BAR: bar;Foobar-foo: baz;")
  end

  it "is gets with []?" do
    headers = HTTP::Headers.new
    headers["foo"]?.should be_nil

    headers["Foo"] = "bar"
    headers["foo"]?.should eq("bar")
  end

  it "fetches" do
    headers = HTTP::Headers{"Foo" => "bar"}
    headers.fetch("foo").should eq("bar")
  end

  it "fetches with default value" do
    headers = HTTP::Headers.new
    headers.fetch("foo", "baz").should eq("baz")

    headers["Foo"] = "bar"
    headers.fetch("foo", "baz").should eq("bar")
  end

  it "fetches with block" do
    headers = HTTP::Headers.new
    headers.fetch("foo") { |k| "#{k}baz" }.should eq("foobaz")

    headers["Foo"] = "bar"
    headers.fetch("foo") { "baz" }.should eq("bar")
  end

  it "has key" do
    headers = HTTP::Headers{"Foo" => "bar"}
    headers.has_key?("foo").should be_true
    headers.has_key?("bar").should be_false
  end

  it "deletes" do
    headers = HTTP::Headers{"Foo" => "bar"}
    headers.delete("foo").should eq("bar")
    headers.empty?.should be_true
  end

  it "equals another hash" do
    headers = HTTP::Headers{"Foo" => "bar"}
    headers.should eq({"foo" => "bar"})
  end

  it "dups" do
    headers = HTTP::Headers{"Foo" => "bar"}
    other = headers.dup
    other.should be_a(HTTP::Headers)
    other["foo"].should eq("bar")

    other["Baz"] = "Qux"
    headers["baz"]?.should be_nil
  end

  it "clones" do
    headers = HTTP::Headers{"Foo" => "bar"}
    other = headers.clone
    other.should be_a(HTTP::Headers)
    other["foo"].should eq("bar")

    other["Baz"] = "Qux"
    headers["baz"]?.should be_nil
  end

  it "adds string" do
    headers = HTTP::Headers.new
    headers.add("foo", "bar")
    headers.add("foo", "baz")
    headers["foo"].should eq("bar,baz")
  end

  it "adds array of string" do
    headers = HTTP::Headers.new
    headers.add("foo", "bar")
    headers.add("foo", ["baz", "qux"])
    headers["foo"].should eq("bar,baz,qux")
  end

  it "gets all values" do
    headers = HTTP::Headers{"foo" => "bar"}
    headers.get("foo").should eq(["bar"])

    headers.get?("foo").should eq(["bar"])
    headers.get?("qux").should be_nil
  end

  it "does to_s" do
    headers = HTTP::Headers{"Foo_quux" => "bar", "Baz-Quux" => ["a", "b"]}
    headers.to_s.should eq(%(HTTP::Headers{"Foo_quux" => "bar", "Baz-Quux" => ["a", "b"]}))
  end

  it "merges and return self" do
    headers = HTTP::Headers.new
    headers.should be headers.merge!({"foo" => "bar"})
  end

  it "matches word" do
    headers = HTTP::Headers{"foo" => "bar"}
    headers.includes_word?("foo", "bar").should be_true
    headers.includes_word?("foo", "ba").should be_false
    headers.includes_word?("foo", "ar").should be_false
  end

  it "matches word with comma separated value" do
    headers = HTTP::Headers{"foo" => "bar, baz"}
    headers.includes_word?("foo", "bar").should be_true
    headers.includes_word?("foo", "baz").should be_true
    headers.includes_word?("foo", "ba").should be_false
  end

  it "matches word with comma separated value, case insensitive (#3626)" do
    headers = HTTP::Headers{"foo" => "BaR, BAZ"}
    headers.includes_word?("foo", "bar").should be_true
    headers.includes_word?("foo", "baz").should be_true
    headers.includes_word?("foo", "BAR").should be_true
    headers.includes_word?("foo", "ba").should be_false
  end

  it "doesn't match empty string" do
    headers = HTTP::Headers{"foo" => "bar, baz"}
    headers.includes_word?("foo", "").should be_false
  end

  it "matches word with comma separated value, partial match" do
    headers = HTTP::Headers{"foo" => "bar, bazo, baz"}
    headers.includes_word?("foo", "baz").should be_true
  end

  it "matches word among headers" do
    headers = HTTP::Headers.new
    headers.add("foo", "bar")
    headers.add("foo", "baz")
    headers.includes_word?("foo", "bar").should be_true
    headers.includes_word?("foo", "baz").should be_true
  end

  it "does not matches word if missing header" do
    headers = HTTP::Headers.new
    headers.includes_word?("foo", "bar").should be_false
    headers.includes_word?("foo", "").should be_false
  end

  it "can create header value with all US-ASCII visible chars (#2999)" do
    headers = HTTP::Headers.new
    value = (32..126).map(&.chr).join
    headers.add("foo", value)
  end

  it "validates content" do
    headers = HTTP::Headers.new
    valid_value = "foo"
    invalid_value = "\r\nLocation: http://example.com"
    headers.valid_value?(valid_value).should be_true
    headers.valid_value?(invalid_value).should be_false
    headers.add?("foo", valid_value).should be_true
    headers.add?("foo", [valid_value]).should be_true
    headers.add?("foobar", invalid_value).should be_false
    headers.add?("foobar", [invalid_value]).should be_false
  end
end
