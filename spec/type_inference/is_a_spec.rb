require 'spec_helper'

describe 'Type inference: is_a?' do
  it "is bool" do
    assert_type("1.is_a?(Bool)") { bool }
  end
end
