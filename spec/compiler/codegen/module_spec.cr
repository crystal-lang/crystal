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
      y = x.as(Moo)

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

      module Moo
      end

      module Moo::Sub
        include Moo
      end

      class File2
        include Moo::Sub
      end

      file = File2.new
      file2 = file.as(Moo)

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
      y = x.as(Moo)

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
        (Foo.new || Bar.new).as(Moo)
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
      a = false.as(Moo)
      if a
        1
      else
        2
      end
      )).to_i.should eq(2)
  end

  it "declares and includes generic module, in macros T is a tuple literal" do
    run(%(
      module Moo(*T)
        def t
          {{T.class_name}}
        end
      end

      class Foo
        include Moo(Int32, Char)
      end

      Foo.new.t
      )).to_string.should eq("TupleLiteral")
  end

  it "can instantiate generic module" do
    run(%(
      struct Int32
        def self.foo
          10
        end
      end

      module Foo(T)
        def self.foo
          T.foo
        end
      end

      Foo(Int32).foo
      )).to_i.should eq(10)
  end

  it "can use generic module as instance variable type" do
    run(%(
      module Moo(T)
        def foo
          1
        end
      end

      class Foo
        include Moo(Int32)
      end

      class Bar
        include Moo(Int32)

        def foo
          2
        end
      end

      class Mooer
        def initialize(@moo : Moo(Int32))
        end

        def moo
          @moo.foo
        end
      end

      mooer = Mooer.new(Foo.new)
      x = mooer.moo

      mooer = Mooer.new(Bar.new)
      y = mooer.moo

      x &+ y
      )).to_i.should eq(3)
  end

  it "can use generic module as instance variable type (2)" do
    run(%(
      module Moo(T)
        def foo
          1
        end
      end

      class Foo(T)
        include Moo(T)
      end

      class Bar(T)
        include Moo(T)

        def foo
          2
        end
      end

      class Mooer
        def initialize(@moo : Moo(Int32))
        end

        def moo
          @moo.foo
        end
      end

      mooer = Mooer.new(Foo(Int32).new)
      x = mooer.moo

      mooer = Mooer.new(Bar(Int32).new)
      y = mooer.moo

      x &+ y
      )).to_i.should eq(3)
  end

  it "casts to union of module that is included in other module (#3323)" do
    run(%(
      require "prelude"

      module Moo
        def moo
          0
        end
      end

      module Moo2
        include Moo
      end

      class Foo
        include Moo2
      end

      class Bar < Foo
        def moo
          10
        end
      end

      struct Baz
        include Moo
      end

      bar = Bar.new.as(Int32 | Moo)
      bar.as(Moo).moo
      )).to_i.should eq(10)
  end

  it "casts to union of generic module that is included in other module (#3323)" do
    run(%(
      require "prelude"

      module Moo(T)
        def moo
          0
        end
      end

      module Moo2(T)
        include Moo(T)
      end

      class Foo
        include Moo2(Char)
      end

      class Bar < Foo
        def moo
          10
        end
      end

      struct Baz
        include Moo(Char)
      end

      bar = Bar.new.as(Int32 | Moo(Char))
      bar.as(Moo(Char)).moo
      )).to_i.should eq(10)
  end

  it "codegens dispatch of union with module (#3647)" do
    run(%(
      module Moo
      end

      class Foo
        include Moo
      end

      class Bar < Foo
      end

      def foo(x : Int32)
        1
      end

      def foo(x)
        234
      end

      m = Bar.new.as(Moo)
      a = m || 1
      foo(a)
      )).to_i.should eq(234)
  end
end
