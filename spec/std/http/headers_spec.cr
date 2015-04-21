require "spec"
require "http/headers"

describe HTTP::Headers do
  it "is empty" do
    headers = HTTP::Headers.new
    expect(headers.empty?).to be_true
  end

  it "is case insensitive" do
    headers = HTTP::Headers{"Foo": "bar"}
    expect(headers["foo"]).to eq("bar")
  end

  it "is gets with []?" do
    headers = HTTP::Headers.new
    expect(headers["foo"]?).to be_nil

    headers["Foo"] = "bar"
    expect(headers["foo"]?).to eq("bar")
  end

  it "fetches" do
    headers = HTTP::Headers{"Foo": "bar"}
    expect(headers.fetch("foo")).to eq("bar")
  end

  it "fetches with default value" do
    headers = HTTP::Headers.new
    expect(headers.fetch("foo", "baz")).to eq("baz")

    headers["Foo"] = "bar"
    expect(headers.fetch("foo", "baz")).to eq("bar")
  end

  it "fetches with block" do
    headers = HTTP::Headers.new
    expect(headers.fetch("foo") { |k| "#{k}baz" }).to eq("Foobaz")

    headers["Foo"] = "bar"
    expect(headers.fetch("foo") { "baz" }).to eq("bar")
  end

  it "has key" do
    headers = HTTP::Headers{"Foo": "bar"}
    expect(headers.has_key?("foo")).to be_true
    expect(headers.has_key?("bar")).to be_false
  end

  it "deletes" do
    headers = HTTP::Headers{"Foo": "bar"}
    expect(headers.delete("foo")).to eq("bar")
    expect(headers.empty?).to be_true
  end

  it "equals another hash" do
    headers = HTTP::Headers{"Foo": "bar"}
    expect(headers).to eq({"foo": "bar"})
  end

  it "dups" do
    headers = HTTP::Headers{"Foo": "bar"}
    other = headers.dup
    expect(other).to be_a(HTTP::Headers)
    expect(other["foo"]).to eq("bar")

    other["Baz"] = "Qux"
    expect(headers["baz"]?).to be_nil
  end

  it "clones" do
    headers = HTTP::Headers{"Foo": "bar"}
    other = headers.clone
    expect(other).to be_a(HTTP::Headers)
    expect(other["foo"]).to eq("bar")

    other["Baz"] = "Qux"
    expect(headers["baz"]?).to be_nil
  end
end
