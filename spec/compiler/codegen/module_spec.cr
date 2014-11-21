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

      class Pointer
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
    build(%(
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
end
