require 'spec_helper'

describe 'Code gen: declare var' do
  it "codegens declare var and read it" do
    run("a :: Int32; a") # TODO: initialize to zero?
  end

  it "codegens declare var and changes it" do
    run("a :: Int32; while 1 == 1; a = 10; break; end; a").to_i.should eq(10)
  end
end
