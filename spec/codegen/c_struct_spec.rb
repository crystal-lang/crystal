require 'spec_helper'

describe 'Code gen: struct' do
  let(:struct) { 'lib Foo; struct Bar; x : Int32; y : Float32; end; end' }

  it "codegens struct property default value" do
    run("#{struct}; bar = Foo::Bar.new; bar.x").to_i.should eq(0)
  end

  it "codegens struct property setter" do
    run("#{struct}; bar = Foo::Bar.new; bar.y = 2.5_f32; bar.y").to_f.should eq(2.5)
  end

  it "codegens struct property setter" do
    run("#{struct}; bar = Foo::Bar.new; p = bar.ptr; p.value.y = 2.5_f32; bar.y").to_f.should eq(2.5)
  end

  it "codegens set struct value with constant" do
    run("#{struct}; CONST = 1; bar = Foo::Bar.new; bar.x = CONST; bar.x").to_i.should eq(1)
  end

  it "codegens union inside struct" do
    run(%q(
      lib Foo
        union Bar
          x : Int32
          y : Int64
        end

        struct Baz
          lala : Bar
        end
      end

      a = Foo::Baz.new
      a.lala.x = 10
      a.lala.x
      )).to_i.should eq(10)
  end
end
