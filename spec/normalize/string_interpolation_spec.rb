require 'spec_helper'

describe 'Normalize: string interpolation' do
  it "normalizes string interpolation" do
    assert_normalize %q("foo#{bar}baz"), %q(((((::StringBuilder.new) << "foo") << bar()) << "baz").to_s)
  end
end
