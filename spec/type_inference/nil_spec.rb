require 'spec_helper'

describe 'Type inference: nil' do
  it "types nil" do
    assert_type('nil') { self.nil }
  end
end
