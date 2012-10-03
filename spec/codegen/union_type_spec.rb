require 'spec_helper'

describe 'Code gen: union type' do
  pending "codegens union type" do
    run("a = 1; a = 2.5; a").to_f.should eq(2.5)
  end
end
