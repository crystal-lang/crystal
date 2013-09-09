require 'spec_helper'

describe 'Code gen: lib' do
  it "codegens lib var set and get" do
    run(%q(
      lib C
        $errno : Int32
      end

      C.errno = 1
      C.errno
      )).to_i.should eq(1)
  end
end
