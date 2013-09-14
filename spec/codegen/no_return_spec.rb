require 'spec_helper'

describe 'Code gen: no return' do
  it "codegens if with NoReturn on then and union on else" do
    run(%(require "prelude"; (if 1 == 2; exit; else; 1 || 2.5; end).to_i)).to_i.should eq(1)
  end

  it "codegens Pointer(NoReturn).malloc" do
    run(%q(Pointer(NoReturn).malloc(1_u64); 1)).to_i.should eq(1)
  end
end
