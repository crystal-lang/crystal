require "../../spec_helper"

private def sret_param(type)
  {% if LibLLVM::IS_LT_120 %}
    "#{type}* sret"
  {% elsif LibLLVM::IS_LT_150 %}
    "#{type}* sret(#{type})"
  {% else %}
    "ptr sret(#{type})"
  {% end %}
end

# Function names are mangled on MSVC (`CodeGenVisitor.safe_mangling`)
private def fun_name(name)
  {% if flag?(:msvc) %}
    "@" + name.gsub(/[^A-Za-z0-9_]/) { |c| ".#{c[0].ord.to_s(16, upcase: true)}." }
  {% else %}
    %(@"#{name}")
  {% end %}
end

describe "Code gen: return" do
  it "codegens return" do
    run("def foo; return 1; end; foo").to_i.should eq(1)
  end

  it "codegens return followed by another expression" do
    run("def foo; return 1; 2; end; foo").to_i.should eq(1)
  end

  it "codegens return inside if" do
    run("def foo; if 1 == 1; return 1; end; 2; end; foo").to_i.should eq(1)
  end

  it "return from function with union type" do
    run("struct Char; def to_i!; 2; end; end; def foo; return 1 if 1 == 1; 'a'; end; foo.to_i!").to_i.should eq(1)
  end

  it "return union" do
    run("struct Char; def to_i!; 2; end; end; def foo; 1 == 2 ? return 1 : return 'a'; end; foo.to_i!").to_i.should eq(2)
  end

  it "return from function with nilable type" do
    run(%(def foo; return Reference.new if 1 == 1; end; foo.nil?)).to_b.should be_false
  end

  it "return from function with nilable type 2" do
    run(%(def foo; return Reference.new if 1 == 1; end; foo.nil?)).to_b.should be_false
  end

  it "returns empty from function" do
    run(<<-CRYSTAL).to_i.should eq(1)
      struct Nil; def to_i!; 0; end; end
      def foo(x)
        return if x == 1
        1
      end

      foo(2).to_i!
      CRYSTAL
  end

  it "codegens bug with return if true" do
    run(<<-CRYSTAL).to_b.should be_true
      def bar
        return if true
        1
      end

      bar.is_a?(Nil)
      CRYSTAL
  end

  it "codegens assign with if with two returns" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def test
        a = 1 ? return 2 : return 3
      end

      test
      CRYSTAL
  end

  it "doesn't crash when method returns nil and can be inlined" do
    codegen(<<-CRYSTAL)
      def foo : Nil
        1
      end

      foo
      CRYSTAL
  end

  it "returns in var assignment (#3364)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      def bar
        a = nil || return 123
      end

      bar
      CRYSTAL
  end

  it "forms a tuple from multiple return values" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        return 5, 3
      end

      v = foo
      v[0] &- v[1]
      CRYSTAL
  end

  it "flattens splats inside multiple return values" do
    run(<<-CRYSTAL).to_i.should eq(18)
      def foo
        return 1, *{3, 9}, 27
      end

      v = foo
      v[3] &- v[2]
      CRYSTAL
  end

  it "returns large StaticArray through an sret pointer" do
    mod = codegen(<<-CRYSTAL)
      struct StaticArray(T, N)
      end

      def make_arr
        arr = uninitialized StaticArray(Int32, 20)
        arr
      end

      def make_small
        arr = uninitialized StaticArray(Int32, 16)
        arr
      end

      make_arr
      make_small
      CRYSTAL
    str = mod.to_s
    str.should contain(%(#{fun_name "*make_arr:StaticArray(Int32, 20)"}(#{sret_param "[20 x i32]"} %0)))
    str.should contain(%([16 x i32] #{fun_name "*make_small:StaticArray(Int32, 16)"}()))
  end

  it "executes method returning large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(142)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      def make_arr(x)
        arr = uninitialized StaticArray(Int32, 32)
        arr[0] = x
        arr[31] = 100
        arr
      end

      a = make_arr(42)
      a[0] &+ a[31]
      CRYSTAL
  end

  it "executes struct method returning large StaticArray using self" do
    run(<<-CRYSTAL).to_i.should eq(99)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      struct MyStruct
        def initialize(@base : Int32)
        end

        def generate_array(offset)
          arr = uninitialized StaticArray(Int32, 20)
          arr[0] = @base &+ offset
          arr
        end
      end

      s = MyStruct.new(50)
      arr = s.generate_array(49)
      arr[0]
      CRYSTAL
  end

  it "executes explicit return in method returning large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(77)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      def make_arr(early : Bool)
        arr = uninitialized StaticArray(Int32, 24)
        if early
          arr[0] = 77
          return arr
        end
        arr[0] = 11
        arr
      end

      make_arr(true)[0]
      CRYSTAL
  end

  it "executes return from block in method returning large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(42)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      def twice
        yield 1
        yield 2
      end

      def make_arr
        arr = uninitialized StaticArray(Int32, 20)
        twice do |i|
          if i == 2
            arr[0] = 42
            return arr
          end
        end
        arr[0] = 0
        arr
      end

      make_arr[0]
      CRYSTAL
  end

  it "executes method with captured block returning large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(42)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      def make_arr(&block : Int32 -> Int32)
        arr = uninitialized StaticArray(Int32, 20)
        arr[0] = block.call(41)
        arr
      end

      make_arr { |x| x &+ 1 }[0]
      CRYSTAL
  end

  it "executes proc returning large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(42)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      f = -> {
        arr = uninitialized StaticArray(Int32, 20)
        arr[0] = 42
        arr
      }
      f.call[0]
      CRYSTAL
  end

  it "executes method returning struct containing large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(142)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      struct Big
        def initialize(x : Int32)
          @arr = uninitialized StaticArray(Int32, 32)
          @arr[0] = x
          @arr[31] = 100
        end

        def arr
          @arr
        end
      end

      def make_big(x)
        Big.new(x)
      end

      b = make_big(42)
      b.arr[0] &+ b.arr[31]
      CRYSTAL
  end

  it "executes method returning nilable large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(142)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      def find_arr(x)
        if x
          arr = uninitialized StaticArray(Int32, 32)
          arr[0] = 42
          arr[31] = 100
          arr
        end
      end

      sum = 0
      if a = find_arr(true)
        sum &+= a[0] &+ a[31]
      end
      if b = find_arr(false)
        sum &+= b[0]
      end
      sum
      CRYSTAL
  end

  it "executes multidispatch returning large StaticArray" do
    run(<<-CRYSTAL).to_i.should eq(3)
      struct StaticArray(T, N)
        def to_unsafe
          pointerof(@buffer)
        end

        def []=(i, v)
          (to_unsafe + i).value = v
        end

        def [](i)
          (to_unsafe + i).value
        end
      end

      class Foo
        def make
          arr = uninitialized StaticArray(Int32, 20)
          arr[0] = 1
          arr
        end
      end

      class Bar < Foo
        def make
          arr = uninitialized StaticArray(Int32, 20)
          arr[0] = 2
          arr
        end
      end

      foo = 1 == 1 ? Foo.new : Bar.new
      bar = 1 == 1 ? Bar.new : Foo.new
      foo.make[0] &+ bar.make[0]
      CRYSTAL
  end

  it "codegens method returning large StaticArray with debug info" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      struct StaticArray(T, N)
      end

      struct MyStruct
        def initialize(@x : Int32)
        end

        def make(y)
          arr = uninitialized StaticArray(Int32, 20)
          arr
        end
      end

      MyStruct.new(1).make(2)
      CRYSTAL
  end
end
