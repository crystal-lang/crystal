require 'spec_helper'

describe 'Type inference: while' do
  it "types while" do
    assert_type('while true; 1; end') { void }
  end
end