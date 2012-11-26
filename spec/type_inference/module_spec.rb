require 'spec_helper'

describe 'Type inference: module' do
  it "includes module" do
    assert_type("module Foo; def foo; 1; end; end; class Bar; include Foo; end; Bar.new.foo") { int }
  end
end
