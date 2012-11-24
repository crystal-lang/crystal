require 'spec_helper'

describe 'Code gen: struct' do
  it "codegens struct property default value" do
    run('lib Foo; struct Bar; x : Int; y : Float; end; end; bar = Foo::Bar.new; bar.x').to_i.should eq(0)
  end

  it "codegens struct property setter" do
    run('lib Foo; struct Bar; x : Int; y : Float; end; end; bar = Foo::Bar.new; bar.y = 2.5; bar.y').to_f.should eq(2.5)
  end
end
