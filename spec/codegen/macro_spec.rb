require 'spec_helper'

describe 'Code gen: macro' do
  it "expands macro" do
    run(%q(macro foo; "1 + 2"; end; foo)).to_i.should eq(3)
  end
end
