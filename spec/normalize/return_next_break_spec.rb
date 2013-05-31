require 'spec_helper'

describe 'Normalize: return next break' do
  it "removes nodes after return" do
    assert_normalize "return 1; 2", "return 1"
  end

  it "removes nodes after next" do
    assert_normalize "next 1; 2", "next 1"
  end

  it "removes nodes after break" do
    assert_normalize "break 1; 2", "break 1"
  end
end
