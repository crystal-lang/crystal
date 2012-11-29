require 'spec_helper'

describe 'Codegen: method missing' do
  it "codegens method missing" do
    run("class Foo; def method_missing(name, args); args.length; end; end; Foo.new.bar(3, 2, 1)").to_i.should eq(3)
  end
end
