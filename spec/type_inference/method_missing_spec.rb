require 'spec_helper'

describe 'Type inference: method missing' do
  it "types method missing" do
    assert_type("class Foo; def method_missing(name, args); name; end; end; Foo.new.bar") { symbol }
  end

  it "doesn't use method missing if defined in the module" do
    assert_type("def bar; 1; end; class Foo; def foo; bar; end; def method_missing(name, args); name; end; end; Foo.new.foo") { int }
  end
end
