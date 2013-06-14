require 'spec_helper'

describe 'Code gen: enum' do
  let(:enum) { 'lib Foo; enum Bar; X, Y, Z = 10, W; end end' }

  it "codegens enum value" do
    run("#{enum}; Foo::Bar::X").to_i.should eq(0)
  end

  it "codegens enum value 2" do
    run("#{enum}; Foo::Bar::Y").to_i.should eq(1)
  end

  it "codegens enum value 3" do
    run("#{enum}; Foo::Bar::Z").to_i.should eq(10)
  end

  it "codegens enum value 4" do
    run("#{enum}; Foo::Bar::W").to_i.should eq(11)
  end
end
