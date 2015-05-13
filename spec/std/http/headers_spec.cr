require "spec"
require "http/headers"

describe HTTP::Headers do
  it "is empty" do
    headers = HTTP::Headers.new
    headers.empty?.should be_true
  end

  it "is case insensitive" do
    headers = HTTP::Headers{"Foo": "bar"}
    headers["foo"].should eq("bar")
  end

  it "is gets with []?" do
    headers = HTTP::Headers.new
    headers["foo"]?.should be_nil

    headers["Foo"] = "bar"
    headers["foo"]?.should eq("bar")
  end

  it "fetches" do
    headers = HTTP::Headers{"Foo": "bar"}
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
    headers.fetch("foo") { |k| "#{k}baz" }.should eq("Foobaz")

    headers["Foo"] = "bar"
    headers.fetch("foo") { "baz" }.should eq("bar")
  end

  it "has key" do
    headers = HTTP::Headers{"Foo": "bar"}
    headers.has_key?("foo").should be_true
    headers.has_key?("bar").should be_false
  end

  it "deletes" do
    headers = HTTP::Headers{"Foo": "bar"}
    headers.delete("foo").should eq("bar")
    headers.empty?.should be_true
  end

  it "equals another hash" do
    headers = HTTP::Headers{"Foo": "bar"}
    headers.should eq({"foo": "bar"})
  end

  it "dups" do
    headers = HTTP::Headers{"Foo": "bar"}
    other = headers.dup
    other.should be_a(HTTP::Headers)
    other["foo"].should eq("bar")

    other["Baz"] = "Qux"
    headers["baz"]?.should be_nil
  end

  it "clones" do
    headers = HTTP::Headers{"Foo": "bar"}
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
    headers = HTTP::Headers{"foo": "bar"}
    headers.get("foo").should eq(["bar"])

    headers.get?("foo").should eq(["bar"])
    headers.get?("qux").should be_nil
  end

  it "does to_s" do
    headers = HTTP::Headers{"foo": "bar", "baz": ["a", "b"]}
    headers.to_s.should eq(%(HTTP::Headers{"Foo" => "bar", "Baz" => ["a", "b"]}))
  end
end
