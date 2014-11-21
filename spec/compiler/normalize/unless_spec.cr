require "../../spec_helper"

describe "Normalize: unless" do
  it "normalizes unless" do
    assert_normalize "unless 1; 2; end", "if 1\nelse\n  2\nend"
  end
end
