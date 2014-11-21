require "../../spec_helper"

describe "Normalize: string interpolation" do
  it "normalizes string interpolation" do
    assert_normalize "\"foo\#{bar}baz\"", "(((::StringIO.new << \"foo\") << bar) << \"baz\").to_s"
  end

  it "normalizes string interpolation with long string" do
    s = "*" * 200
    assert_normalize "\"foo\#{bar}#{s}\"",
      "((((::StringIO.new(218)) << \"foo\") << bar) << \"#{s}\").to_s"
  end
end
