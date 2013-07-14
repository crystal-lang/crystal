require 'spec_helper'

describe 'Normalize: multi assign' do
  it "normalizes n to n" do
    assert_normalize "a, b, c = 1, 2, 3", "#temp_1 = 1\n#temp_2 = 2\n#temp_3 = 3\na = #temp_1\nb = #temp_2\nc = #temp_3"
  end
end
