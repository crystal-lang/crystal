require 'spec_helper'

describe 'Code gen: pointer' do
  it "get pointer and value of it" do
    run('a = 1; b = ptr(a); b.value').to_i.should eq(1)
  end

  it "get pointer of instance var" do
    run(%q(
      class Foo
        def initialize(value)
          @value = value
        end

        def value_ptr
          ptr(@value)
        end
      end

      foo = Foo.new(10)
      value_ptr = foo.value_ptr
      value_ptr.value
      )).to_i.should eq(10)
  end

  it "set pointer value" do
    run('a = 1; b = ptr(a); b.value = 2; a').to_i.should eq(2)
  end

  it "set pointer of instance var value" do
    run(%q(
      class Foo
        def foo
          p = ptr(@value)
          p.value = 1
        end
        def value
          @value
        end
      end

      f = Foo.new
      f.foo
      f.value)).to_i.should eq(1)
  end

  it "get value of pointer to union" do
    run('a = 1.1; a = 1; b = ptr(a); b.value.to_i').to_i.should eq(1)
  end

  it "set value of pointer to union" do
    run('a = 1.1; p = ptr(a); p.value = 1; a.to_i').to_i.should eq(1)
  end

  it "increment pointer" do
    run(%q(
      class Foo
        def initialize
          @a = 1
          @b = 2
        end
        def value
          p = ptr(@a)
          p += 1
          p.value
        end
      end
      Foo.new.value
    )).to_i.should eq(2)
  end

  it "codegens malloc" do
    run(%q(p = Pointer.malloc(10); p.value = 1; p.value + 1)).to_i.should eq(2)
  end

  it "codegens realloc" do
    run(%q(p = Pointer.malloc(10); p.value = 1; x = p.realloc(20); x.value + 1)).to_i.should eq(2)
  end

  it "codegens pointer cast" do
    run('a = 1L; ptr(a).as(Int).value').to_i.should eq(1)
  end
end