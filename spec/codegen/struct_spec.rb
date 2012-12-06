require 'spec_helper'

describe 'Code gen: struct' do
  let(:struct) { 'lib Foo; struct Bar; x : Int; y : Float; end; end' }
  it "codegens struct property default value" do
    run("#{struct}; bar = Foo::Bar.new; bar.x").to_i.should eq(0)
  end

  it "codegens struct property setter" do
    run("#{struct}; bar = Foo::Bar.new; bar.y = 2.5; bar.y").to_f.should eq(2.5)
  end

  it "codegens struct property setter" do
    run("#{struct}; bar = Foo::Bar.new; p = bar.ptr; p.value.y = 2.5; bar.y").to_f.should eq(2.5)
  end
end
