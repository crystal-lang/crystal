require 'spec_helper'

describe 'Code gen: c union' do
  let(:union) { 'lib Foo; union Bar; x : Int32; y : Int64; z : Float32; end; end' }

  it "codegens union property default value" do
    run("#{union}; bar = Foo::Bar.new; bar.x").to_i.should eq(0)
  end

  it "codegens union property default value 2" do
    run("#{union}; bar = Foo::Bar.new; bar.z").to_f.should eq(0)
  end

  it "codegens union property setter 1" do
    run("#{union}; bar = Foo::Bar.new; bar.x = 42; bar.x").to_i.should eq(42)
  end

  it "codegens union property setter 2" do
    run("#{union}; bar = Foo::Bar.new; bar.z = 42.0_f32; bar.z").to_f.should eq(42.0)
  end

  it "codegens struct inside union" do
    run(%q(
      lib Foo
        struct Baz
          lele : Int64
          lala : Int32
        end

        union Bar
          x : Int32
          y : Int64
          z : Baz
        end
      end

      a = Foo::Bar.new
      a.z = Foo::Baz.new
      a.z.lala = 10
      a.z.lala
      )).to_i.should eq(10)
  end
end
