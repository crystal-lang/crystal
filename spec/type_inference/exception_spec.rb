require 'spec_helper'

describe 'Type inference: exception' do
  it "type is union of main and rescue blocks" do
    assert_type(%(
      begin
        1
      rescue
        'a'
      end
    )) { union_of(int32, char) }
  end
end
