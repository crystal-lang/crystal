require 'spec_helper'

describe 'Type inference: method missing' do
  it "types method missing" do
    assert_type(%q(require "array"; class Foo; def method_missing(name, args); name; end; end; Foo.new.bar)) { symbol }
  end

  it "doesn't use method missing if defined in the module" do
    assert_type(%q(require "array"; def bar; 1; end; class Foo; def foo; bar; end; def method_missing(name, args); name; end; end; Foo.new.foo)) { int }
  end

  it "create symbol literal with method name as string" do
    input = parse %q(require "array"; class Foo; def method_missing(name, args); 1; end; end; Foo.new < 1)
    mod, input = infer_type input
    mod.symbols.to_a.should eq(['<'])
  end
end
