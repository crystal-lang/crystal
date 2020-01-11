require "../../spec_helper"

describe "Normalize: string interpolation" do
  it "normalizes string interpolation" do
    assert_expand %("foo\#{bar}baz"), %(::String.interpolation("foo", bar, "baz"))
  end

  it "normalizes string interpolation with multiple lines" do
    assert_expand %("foo\n\#{bar}\nbaz\nqux\nfox"), %(::String.interpolation("foo\\n", bar, "\\nbaz\\nqux\\nfox"))
  end

  it "normalizes heredoc" do
    assert_normalize "<<-FOO\nhello\nFOO", %("hello")
  end
end
