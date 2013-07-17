require 'spec_helper'

describe 'Code gen: pointer' do
  it "get pointer and value of it" do
    run('a = 1; b = a.ptr; b.value').to_i.should eq(1)
  end

  it "get pointer of instance var" do
    run(%q(
      class Foo
        def initialize(value)
          @value = value
        end

        def value_ptr
          @value.ptr
        end
      end

      foo = Foo.new(10)
      value_ptr = foo.value_ptr
      value_ptr.value
      )).to_i.should eq(10)
  end

  it "set pointer value" do
    run('a = 1; b = a.ptr; b.value = 2; a').to_i.should eq(2)
  end

  it "get value of pointer to union" do
    run('a = 1.1; a = 1; b = a.ptr; b.value.to_i').to_i.should eq(1)
  end

  it "sets value of pointer to union" do
    run('p = Pointer(Int32|Float64).malloc(1); a = 1; a = 2.5; p.value = a; p.value.to_i').to_i.should eq(2)
  end

  it "increment pointer" do
    run(%q(
      class Foo
        def initialize
          @a = 1
          @b = 2
        end
        def value
          p = @a.ptr
          p += 1
          p.value
        end
      end
      Foo.new.value
    )).to_i.should eq(2)
  end

  it "codegens malloc" do
    run(%q(p = Pointer(Int32).malloc(10); p.value = 1; p.value + 1)).to_i.should eq(2)
  end

  it "codegens realloc" do
    run(%q(p = Pointer(Int32).malloc(10); p.value = 1; x = p.realloc(20); x.value + 1)).to_i.should eq(2)
  end

  it "codegens pointer cast" do
    run('a = 1_i64; a.ptr.as(Int32).value').to_i.should eq(1)
  end

  it "codegens pointer null" do
    run("Pointer(Int32).null.address").to_i.should eq(0)
  end

  it "gets pointer of instance variable in hierarchy type" do
    run(%q(
      class Foo
        def initialize
          @a = 1
        end

        def foo
          @a.ptr
        end
      end

      class Bar < Foo
      end

      foo = Foo.new || Bar.new
      x = foo.foo
      x.value
      )).to_i.should eq(1)
  end

  it "sets value of pointer to struct" do
    run(%q(
      lib C
        struct Color
          r, g, b, a : UInt8
        end
      end

      color = C::Color.new
      color.r = 10_u8

      color2 = C::Color.new
      color2.r = 20_u8

      p = color.ptr
      p.value = color2

      color.r
      )).to_i.should eq(20)
  end

  it "changes through var and reads from pointer" do
    run(%q(
      x = 1
      px = x.ptr
      x = 2
      px.value
      )).to_i.should eq(2)
  end
end
