require 'spec_helper'

describe 'Codegen: exceptin' do

  pending "executes normally the main block" do
    run(%q(
      begin
        1
      rescue
        2
      end
    )).to_i.should eq(1)
  end

  pending "executes rescue all block" do
    run(%q(
      require "prelude"
      begin
        raise 1
        1
      rescue
        2
      end
    )).to_i.should eq(2)
  end

end
