require "../../spec_helper"

describe "Code gen: module" do
  it "codegens pointer of module with method" do
    run("
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo.new
      p.value.foo
      ").to_i.should eq(1)
  end

  it "codegens pointer of module with method with two including types" do
    run("
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      class Bar
        include Moo

        def foo
          2
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo.new
      p.value = Bar.new
      p.value.foo
      ").to_i.should eq(2)
  end

  it "codegens pointer of module with method with two including types with one struct" do
    run("
      module Foo
      end

      class Bar
        include Foo

        def foo
          1
        end
      end

      struct Coco
        include Foo

        def foo
          2
        end
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new
      p.value = Coco.new
      p.value.foo
      ").to_i.should eq(2)
  end

  it "codegens pointer of module with method with two including types with one struct (2)" do
    run("
      module Foo
      end

      class Bar
        include Foo

        def foo
          1
        end
      end

      struct Coco
        include Foo

        def foo
          2
        end
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new
      p.value = Coco.new
      x = p.value
      x.foo
      ").to_i.should eq(2)
  end

  it "codegens pointer of module and pass value to method" do
    run(%(
      module Foo
      end

      class Bar
        include Foo

        def foo
          1
        end
      end

      def foo(x)
        x.foo
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new
      foo p.value
      )).to_i.should eq(1)
  end

  it "codegens pointer of module with block" do
    run(%(
      require "prelude"

      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      struct Pointer
        def each
          yield value
        end
      end

      a = Pointer(Moo).malloc(1_u64)
      a.value = Foo.new
      x = nil
      a.each do |io|
        x = io
      end
      x.not_nil!.foo
      )).to_i.should eq(1)
  end

  it "codegens module with virtual type" do
    run(%(
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Bar.new
      p.value.foo
      )).to_i.should eq(2)
  end

  it "declares proc with module type" do
    run(%(
      module Moo
        def moo
          1
        end
      end

      class Foo
        include Moo
      end

      class Bar
        include Moo
      end

      foo = ->(x : Moo) { x.moo }
      foo.call(Bar.new)
      )).to_i.should eq(1)
  end

  it "declares proc with module type and invoke it with two different types that return themselves" do
    codegen(%(
      module Moo
        def moo
          1
        end
      end

      class Foo
        include Moo
      end

      struct Bar
        include Moo
      end

      foo = ->(x : Moo) { x }
      foo.call(Foo.new)
      foo.call(Bar.new)
      ))
  end

  it "codegens proc of a module that was never included" do
    codegen(%(
      require "prelude"

      module Moo
      end

      ->(x : Moo) { x.foo }
      1
      ))
  end

  it "codegens proc of module when generic type includes it" do
    run(%(
      module Moo
      end

      class Foo(T)
        include Moo

        def foo
          3
        end
      end

      z = ->(x : Moo) { x.foo }
      z.call(Foo(Int32).new)
      )).to_i.should eq(3)
  end

  it "invokes method on yielded module that has no instances (#1079)" do
    run(%(
      require "prelude"

      module Mod
      end

      def foo
        ptr = Pointer(Mod).malloc(1_u64)
        yield ptr.value
        123
      rescue
        456
      end

      foo { |x| x.coco }
      )).to_i.should eq(456)
  end

  it "expands modules to its including types (#1916)" do
    run(%(
      class Reference
        def method(other : Reference)
          1
        end

        def method(other)
          2
        end
      end

      module Moo
      end

      class Foo
        include Moo
      end

      class Bar
        include Moo
      end

      x = Foo.new
      y = x as Moo

      x.method(y)
      )).to_i.should eq(1)
  end

  it "expands modules to its including types (2) (#1916)" do
    run(%(
      class Reference
        def method(other : Reference)
          1
        end

        def method(other)
          2
        end
      end

      module IO2
      end

      module IO2::Sub
        include IO2
      end

      class File2
        include IO2::Sub
      end

      file = File2.new
      file2 = file as IO2

      file.method(file2)
      )).to_i.should eq(1)
  end

  it "expands modules to its including types (3) (#1916)" do
    run(%(
      class Object
        def method(other : Reference)
          1
        end

        def method(other)
          2
        end
      end

      module Moo
      end

      class Foo
        include Moo
      end

      struct Bar
        include Moo
      end

      x = Bar.new
      y = x as Moo

      x.method(y)
      )).to_i.should eq(2)
  end

  it "codegens cast to module with class and struct to nilable module" do
    run(%(
      module Moo
        def bar
          10
        end
      end

      class Foo
        include Moo
      end

      struct Bar
        include Moo
      end

      def moo
        (Foo.new || Bar.new) as Moo
      end

      moo = moo()
      nilable = moo || nil
      if nilable
        nilable.bar
      else
        20
      end
      )).to_i.should eq(10)
  end

  it "codegens cast to module that includes bool" do
    run(%(
      module Moo
      end

      struct Bool
        include Moo
      end

      class Foo
        include Moo
      end

      Foo.new
      a = false as Moo
      if a
        1
      else
        2
      end
      )).to_i.should eq(2)
  end
end
