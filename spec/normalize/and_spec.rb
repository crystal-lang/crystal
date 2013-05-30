require 'spec_helper'

describe 'Normalize: and' do
  it "normalizes and without variable" do
    assert_normalize "a && b", "if #temp_1 = a()\n  b()\nelse\n  #temp_1\nend"
  end

  it "normalizes and with variable on the left" do
    assert_normalize "a = 1; a && b", "a = 1\nif a\n  b()\nelse\n  a\nend"
  end
end