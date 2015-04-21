require "../../spec_helper"

describe "Code gen: pointer" do
  it "get pointer and value of it" do
    expect(run("a = 1; b = pointerof(a); b.value").to_i).to eq(1)
  end

  it "get pointer of instance var" do
    expect(run("
      class Foo
        def initialize(value)
          @value = value
        end

        def value_ptr
          pointerof(@value)
        end
      end

      foo = Foo.new(10)
      value_ptr = foo.value_ptr
      value_ptr.value
      ").to_i).to eq(10)
  end

  it "set pointer value" do
    expect(run("a = 1; b = pointerof(a); b.value = 2; a").to_i).to eq(2)
  end

  it "get value of pointer to union" do
    expect(run("a = 1.1; a = 1; b = pointerof(a); b.value.to_i").to_i).to eq(1)
  end

  it "sets value of pointer to union" do
    expect(run("p = Pointer(Int32|Float64).malloc(1_u64); a = 1; a = 2.5; p.value = a; p.value.to_i").to_i).to eq(2)
  end

  it "increments pointer" do
    expect(run("
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
    ").to_i).to eq(2)
  end

  it "codegens malloc" do
    expect(run("p = Pointer(Int32).malloc(10_u64); p.value = 1; p.value + 1_i64").to_i).to eq(2)
  end

  it "codegens realloc" do
    expect(run("p = Pointer(Int32).malloc(10_u64); p.value = 1; x = p.realloc(20_u64); x.value + 1_i64").to_i).to eq(2)
  end

  it "codegens pointer cast" do
    expect(run("a = 1_i64; (pointerof(a) as Int32*).value").to_i).to eq(1)
  end

  it "codegens pointer as if condition" do
    expect(run("a = 0; pointerof(a) ? 1 : 2").to_i).to eq(1)
  end

  it "codegens null pointer as if condition" do
    expect(run("Pointer(Int32).new(0_u64) ? 1 : 2").to_i).to eq(2)
  end

  it "gets pointer of instance variable in virtual type" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "sets value of pointer to struct" do
    expect(run("
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
      ").to_i).to eq(20)
  end

  it "changes through var and reads from pointer" do
    expect(run("
      x = 1
      px = pointerof(x)
      x = 2
      px.value
      ").to_i).to eq(2)
  end

  it "creates pointer by address" do
    expect(run("
      x = Pointer(Int32).new(123_u64)
      x.address
    ").to_i).to eq(123)
  end

  it "calculates pointer diff" do
    expect(run("
      x = 1
      (pointerof(x) + 1_i64) - pointerof(x)
    ").to_i).to eq(1)
  end

  it "can dereference pointer to func" do
    expect(run("
      def foo; 1; end
      x = ->foo
      y = pointerof(x)
      y.value.call
    ").to_i).to eq(1)
  end

  it "gets pointer of argument that is never assigned to" do
    expect(run("
      def foo(x)
        pointerof(x)
      end

      foo(1)
      1
      ").to_i).to eq(1)
  end

  it "codegens nilable pointer type (1)" do
    expect(run("
      p = Pointer(Int32).malloc(1_u64)
      p.value = 3
      a = 1 == 2 ? nil : p
      if a
        a.value
      else
        4
      end
      ").to_i).to eq(3)
  end

  it "codegens nilable pointer type (2)" do
    expect(run("
      p = Pointer(Int32).malloc(1_u64)
      p.value = 3
      a = 1 == 1 ? nil : p
      if a
        a.value
      else
        4
      end
      ").to_i).to eq(4)
  end

  it "codegens nilable pointer type dispatch (1)" do
    expect(run("
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
      ").to_i).to eq(3)
  end

  it "codegens nilable pointer type dispatch (2)" do
    expect(run("
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
      ").to_i).to eq(0)
  end

  it "assigns nil and pointer to nilable pointer type" do
    expect(run("
      class Foo
        def initialize
        end

        def x=(@x)
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
      ").to_i).to eq(3)
  end

  it "gets pointer to constant" do
    expect(run("
      FOO = 1
      pointerof(FOO).value
    ").to_i).to eq(1)
  end

  it "passes pointer of pointer to method" do
    expect(run("
      def foo(x)
        x.value.value
      end

      p = Pointer(Pointer(Int32)).malloc(1_u64)
      p.value = Pointer(Int32).malloc(1_u64)
      p.value.value = 1
      foo p
      ").to_i).to eq(1)
  end

  it "codgens pointer as if condition inside union (1)" do
    expect(run(%(
      ptr = Pointer(Int32).new(0_u64) || Pointer(Float64).new(0_u64)
      if ptr
        1
      else
        2
      end
      )).to_i).to eq(2)
  end

  it "codgens pointer as if condition inside union (2)" do
    expect(run(%(
      if 1 == 1
        ptr = Pointer(Int32).new(0_u64)
      else
        ptr = 10
      end
      ptr ? 20 : 30
      )).to_i).to eq(30)
  end
end
