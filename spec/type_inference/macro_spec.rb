require 'spec_helper'

describe 'Type inference: macro' do
  it "types macro" do
    input = parse %q(macro foo; "1"; end; foo)
    mod, input = infer_type input
    input.last.target_macro.should eq(parse "1")
  end
end
