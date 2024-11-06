require "../../spec_helper"

describe "Code gen: pointer" do
  it "get pointer and value of it" do
    run("a = 1; b = pointerof(a); b.value").to_i.should eq(1)
  end

  it "get pointer of instance var" do
    run("
      class Foo
        def initialize(value : Int32)
          @value = value
        end

        def value_ptr
          pointerof(@value)
        end
      end

      foo = Foo.new(10)
      value_ptr = foo.value_ptr
      value_ptr.value
      ").to_i.should eq(10)
  end

  it "set pointer value" do
    run("a = 1; b = pointerof(a); b.value = 2; a").to_i.should eq(2)
  end

  it "get value of pointer to union" do
    run("a = 1.1; a = 1; b = pointerof(a); b.value.to_i!").to_i.should eq(1)
  end

  it "sets value of pointer to union" do
    run("p = Pointer(Int32|Float64).malloc(1_u64); a = 1; a = 2.5; p.value = a; p.value.to_i!").to_i.should eq(2)
  end

  it "increments pointer" do
    run("
      class Foo
        def initialize
          @a = 1
          @b = 2
        end
        def value
          p = pointerof(@a)
          p += 1_i64
          p.value
        end
      end
      Foo.new.value
    ").to_i.should eq(2)
  end

  it "codegens malloc" do
    run("p = Pointer(Int32).malloc(10_u64); p.value = 1; p.value &+ 1_i64").to_i.should eq(2)
  end

  it "codegens realloc" do
    run("p = Pointer(Int32).malloc(10_u64); p.value = 1; x = p.realloc(20_u64); x.value &+ 1_i64").to_i.should eq(2)
  end

  it "codegens pointer cast" do
    run("a = 1_i64; pointerof(a).as(Int32*).value").to_i.should eq(1)
  end

  it "codegens pointer cast to Nil (#8015)" do
    run("a = 1_i64; pointerof(a).as(Nil).nil? ? 3 : 7").to_i.should eq(3)
  end

  it "codegens pointer as if condition" do
    run("a = 0; pointerof(a) ? 1 : 2").to_i.should eq(1)
  end

  it "codegens null pointer as if condition" do
    run("Pointer(Int32).new(0_u64) ? 1 : 2").to_i.should eq(2)
  end

  it "gets pointer of instance variable in virtual type" do
    run("
      class Foo
        def initialize
          @a = 1
        end

        def foo
          pointerof(@a)
        end
      end

      class Bar < Foo
      end

      foo = Foo.new || Bar.new
      x = foo.foo
      x.value
      ").to_i.should eq(1)
  end

  it "sets value of pointer to struct" do
    run("
      lib LibC
        struct Color
          r, g, b, a : UInt8
        end
      end

      color = Pointer(LibC::Color).malloc(1_u64)
      color.value.r = 10_u8

      color2 = Pointer(LibC::Color).malloc(1_u64)
      color2.value.r = 20_u8

      color.value = color2.value

      color.value.r
      ").to_i.should eq(20)
  end

  it "changes through var and reads from pointer" do
    run("
      x = 1
      px = pointerof(x)
      x = 2
      px.value
      ").to_i.should eq(2)
  end

  it "creates pointer by address" do
    run("
      x = Pointer(Int32).new(123_u64)
      x.address
    ").to_i.should eq(123)
  end

  it "calculates pointer diff" do
    run("
      x = 1
      (pointerof(x) + 1_i64) - pointerof(x)
    ").to_i.should eq(1)
  end

  it "can dereference pointer to func" do
    run("
      def foo; 1; end
      x = ->foo
      y = pointerof(x)
      y.value.call
    ").to_i.should eq(1)
  end

  it "gets pointer of argument that is never assigned to" do
    run("
      def foo(x)
        pointerof(x)
      end

      foo(1)
      1
      ").to_i.should eq(1)
  end

  it "codegens nilable pointer type (1)" do
    run("
      p = Pointer(Int32).malloc(1_u64)
      p.value = 3
      a = 1 == 2 ? nil : p
      if a
        a.value
      else
        4
      end
      ").to_i.should eq(3)
  end

  it "codegens nilable pointer type (2)" do
    run("
      p = Pointer(Int32).malloc(1_u64)
      p.value = 3
      a = 1 == 1 ? nil : p
      if a
        a.value
      else
        4
      end
      ").to_i.should eq(4)
  end

  it "codegens nilable pointer type dispatch (1)" do
    run("
      def foo(x : Pointer)
        x.value
      end

      def foo(x : Nil)
        0
      end

      p = Pointer(Int32).malloc(1_u64)
      p.value = 3
      a = 1 == 1 ? p : nil
      foo(a)
      ").to_i.should eq(3)
  end

  it "codegens nilable pointer type dispatch (2)" do
    run("
      def foo(x : Pointer)
        x.value
      end

      def foo(x : Nil)
        0
      end

      p = Pointer(Int32).malloc(1_u64)
      p.value = 3
      a = 1 == 1 ? nil : p
      foo(a)
      ").to_i.should eq(0)
  end

  it "assigns nil and pointer to nilable pointer type" do
    run("
      class Foo
        def initialize
        end

        def x=(@x : Int32*?)
        end

        def x
          @x
        end
      end

      p = Pointer(Int32).malloc(1_u64)
      p.value = 3

      foo = Foo.new
      foo.x = nil
      foo.x = p
      z = foo.x
      if z
        p.value
      else
        2
      end
      ").to_i.should eq(3)
  end

  it "gets pointer to constant" do
    run(%(
      require "prelude"
      FOO = 1
      pointerof(FOO).value
    )).to_i.should eq(1)
  end

  it "passes pointer of pointer to method" do
    run("
      def foo(x)
        x.value.value
      end

      p = Pointer(Pointer(Int32)).malloc(1_u64)
      p.value = Pointer(Int32).malloc(1_u64)
      p.value.value = 1
      foo p
      ").to_i.should eq(1)
  end

  it "codegens pointer as if condition inside union (1)" do
    run(%(
      ptr = Pointer(Int32).new(0_u64) || Pointer(Float64).new(0_u64)
      if ptr
        1
      else
        2
      end
      )).to_i.should eq(2)
  end

  it "codegens pointer as if condition inside union (2)" do
    run(%(
      if 1 == 1
        ptr = Pointer(Int32).new(0_u64)
      else
        ptr = 10
      end
      ptr ? 20 : 30
      )).to_i.should eq(30)
  end

  it "can use typedef pointer value get and set (#630)" do
    codegen(%(
      lib LibFoo
        type MyObj = Int32*
        fun foo : MyObj
      end

      LibFoo.foo.value
      LibFoo.foo.value = 1
      ))
  end

  it "does pointerof class variable" do
    run(%(
      class Foo
        @@a = 1

        def self.a_ptr
          pointerof(@@a)
        end

        def self.a
          @@a
        end
      end

      Foo.a_ptr.value = 2
      Foo.a
      )).to_i.should eq(2)
  end

  it "does pointerof class variable with class" do
    run(%(
      class Bar
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Foo
        @@a = Bar.new(1)

        def self.a_ptr
          pointerof(@@a)
        end

        def self.a
          @@a
        end
      end

      Foo.a_ptr.value = Bar.new(2)
      Foo.a.x
      )).to_i.should eq(2)
  end

  it "does pointerof read variable" do
    run(%(
      class Foo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      foo = Foo.new
      pointerof(foo.@x).value = 123
      foo.x
      )).to_i.should eq(123)
  end

  it "can assign nil to void pointer" do
    codegen(%(
      ptr = Pointer(Void).malloc(1_u64)
      ptr.value = ptr.value
      ))
  end

  it "can pass any pointer to something expecting void* in lib call" do
    codegen(%(
      lib LibFoo
        fun foo(x : Void*) : Float64
      end

      LibFoo.foo(Pointer(Int32).malloc(1_u64))
      ))
  end

  it "can pass any pointer to something expecting void* in lib call, with to_unsafe" do
    codegen(%(
      lib LibFoo
        fun foo(x : Void*) : Float64
      end

      class Foo
        def to_unsafe
          Pointer(Int32).malloc(1_u64)
        end
      end

      LibFoo.foo(Foo.new)
      ))
  end

  it "uses correct llvm module for typedef metaclass (#2877)" do
    run(%(
      lib LibFoo
        type Foo = Void*
        type Bar = Void*
      end

      class Class
        def foo
          foo(1)
        end

        def foo(x)
        end
      end

      struct Pointer
        def foo
          T.foo
        end
      end

      foo = uninitialized LibFoo::Foo*
      bar = uninitialized LibFoo::Bar*
      foo.foo
      bar.foo
      1
      ))
  end

  it "passes arguments correctly for typedef metaclass (#8544)" do
    run <<-CRYSTAL
      lib LibFoo
        type Foo = Void*
      end

      class Class
        def foo(x)
          x
        end
      end

      x = 1
      LibFoo::Foo.foo(x)
      Pointer(Void).foo(x)
      CRYSTAL
  end

  it "generates correct code for Pointer.malloc(0) (#2905)" do
    run(%(
      class Foo
        def initialize(@value : Int32)
        end

        def value
          @value
        end
      end

      foo = Foo.new(3)
      Pointer(Int32 | UInt8[9]).malloc(0_u64)
      foo.value
      )).to_i.should eq(3)
  end

  it "compares pointers through typedef" do
    run(%(
      module Comparable(T)
        def ==(other : T)
          (self <=> other) == 0
        end
      end

      struct Pointer(T)
        include Comparable(Pointer)

        def <=>(other : Pointer)
          0
        end
      end

      lib LibFoo
        type Ptr = Void*
      end

      ptr = Pointer(Void).malloc(1_u64).as(LibFoo::Ptr)
      ptr == ptr
      )).to_b.should be_true
  end

  # FIXME: `$external_var` implies __declspec(dllimport), but we only have an
  # object file, so MinGW-w64 fails linking (actually MSVC also emits an
  # LNK4217 linker warning)
  {% unless flag?(:win32) && flag?(:gnu) %}
    it "takes pointerof lib external var" do
      test_c(
        %(
          int external_var = 0;
        ),
        %(
          lib LibFoo
            $external_var : Int32
          end

          LibFoo.external_var = 1

          ptr = pointerof(LibFoo.external_var)
          x = ptr.value

          ptr.value = 10
          y = ptr.value

          ptr.value = 100
          z = LibFoo.external_var

          x + y + z
        ), &.to_i.should eq(111))
    end
  {% end %}
end
