{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "pointers" do
    it "interprets pointer set and get (int)" do
      interpret(<<-CRYSTAL).should eq(10)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 10
        ptr.value
      CRYSTAL
    end

    it "interprets pointer set and get (bool)" do
      interpret(<<-CRYSTAL).should be_true
        ptr = Pointer(Bool).malloc(1_u64)
        ptr.value = true
        ptr.value
      CRYSTAL
    end

    it "interprets pointer set and get (clear stack)" do
      interpret(<<-CRYSTAL).should eq(50.unsafe_chr)
        ptr = Pointer(UInt8).malloc(1_u64)
        ptr.value = 50_u8
        ptr.value.unsafe_chr
      CRYSTAL
    end

    it "interprets pointerof, mutates pointer, read var" do
      interpret(<<-CRYSTAL).should eq(2)
        a = 1
        ptr = pointerof(a)
        ptr.value = 2
        a
      CRYSTAL
    end

    it "interprets pointerof, mutates var, read pointer" do
      interpret(<<-CRYSTAL).should eq(2)
        a = 1
        ptr = pointerof(a)
        a = 2
        ptr.value
      CRYSTAL
    end

    it "interprets pointerof and mutates memory (there are more variables)" do
      interpret(<<-CRYSTAL).should eq(2)
        x = 42
        a = 1
        ptr = pointerof(a)
        ptr.value = 2
        a
      CRYSTAL
    end

    it "pointerof instance var" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def x_ptr
            pointerof(@x)
          end
        end

        foo = Foo.new(1)
        ptr = foo.x_ptr
        ptr.value = 2
        foo.x
      CRYSTAL
    end

    it "pointerof class var" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          @@x : Int32?

          def self.x_ptr
            pointerof(@@x)
          end

          def self.x
            @@x
          end
        end

        ptr = Foo.x_ptr
        v = ptr.value
        ptr.value = 2
        x = Foo.x
        x || 0
      CRYSTAL
    end

    it "pointerof read instance var" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def x_ptr
            pointerof(@x)
          end
        end

        foo = Foo.new(1)
        ptr = pointerof(foo.@x)
        ptr.value = 2
        foo.x
      CRYSTAL
    end

    it "pointerof read `StaticArray#@buffer` (1)" do
      interpret(<<-CRYSTAL).should eq(2)
        struct StaticArray(T, N)
          def to_unsafe
            pointerof(@buffer)
          end

          def x
            @buffer
          end
        end

        foo = uninitialized Int32[4]
        foo.to_unsafe.value = 2
        foo.x
        CRYSTAL
    end

    it "pointerof read `StaticArray#@buffer` (2)" do
      interpret(<<-CRYSTAL).should eq(2)
        foo = uninitialized Int32[4]
        pointerof(foo.@buffer).value = 2
        foo.@buffer
        CRYSTAL
    end

    it "interprets pointer set and get (union type)" do
      interpret(<<-CRYSTAL).should eq(10)
        ptr = Pointer(Int32 | Bool).malloc(1_u64)
        ptr.value = 10
        value = ptr.value
        if value.is_a?(Int32)
          value
        else
          20
        end
      CRYSTAL
    end

    it "interprets pointer set and get (union type, setter value)" do
      interpret(<<-CRYSTAL).should eq(10)
        ptr = Pointer(Int32 | Bool).malloc(1_u64)
        ptr.value = 10
      CRYSTAL
    end

    it "interprets pointer new and pointer address" do
      interpret(<<-CRYSTAL).should eq(123_u64)
        ptr = Pointer(Int32 | Bool).new(123_u64)
        ptr.address
      CRYSTAL
    end

    it "interprets pointer diff" do
      interpret(<<-CRYSTAL).should eq(8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
      CRYSTAL
    end

    it "interprets pointer diff, negative" do
      interpret(<<-CRYSTAL).should eq(-8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr2 - ptr1
      CRYSTAL
    end

    it "discards pointer malloc" do
      interpret(<<-CRYSTAL).should eq(1)
        Pointer(Int32).malloc(1_u64)
        1
      CRYSTAL
    end

    it "discards pointer get" do
      interpret(<<-CRYSTAL).should eq(1)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value
        1
      CRYSTAL
    end

    it "discards pointer set" do
      interpret(<<-CRYSTAL).should eq(1)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 1
      CRYSTAL
    end

    it "discards pointer new" do
      interpret(<<-CRYSTAL).should eq(1)
        Pointer(Int32).new(1_u64)
        1
      CRYSTAL
    end

    it "discards pointer diff" do
      interpret(<<-CRYSTAL).should eq(1)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
        1
      CRYSTAL
    end

    it "discards pointerof" do
      interpret(<<-CRYSTAL).should eq(3)
        a = 1
        pointerof(a)
        3
      CRYSTAL
    end

    it "interprets pointer add" do
      interpret(<<-CRYSTAL).should eq(9)
        ptr = Pointer(Int32).new(1_u64)
        ptr2 = ptr + 2_i64
        ptr2.address
      CRYSTAL
    end

    it "discards pointer add" do
      interpret(<<-CRYSTAL).should eq(3)
        ptr = Pointer(Int32).new(1_u64)
        ptr + 2_i64
        3
      CRYSTAL
    end

    it "interprets pointer realloc" do
      interpret(<<-CRYSTAL).should eq(3)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr2 = ptr.realloc(2_u64)
        3
      CRYSTAL
    end

    it "discards pointer realloc" do
      interpret(<<-CRYSTAL).should eq(3)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.realloc(2_u64)
        3
      CRYSTAL
    end

    it "interprets pointer realloc wrapper" do
      interpret(<<-CRYSTAL).should eq(3)
        struct Pointer(T)
          def realloc(n)
            realloc(n.to_u64)
          end
        end

        ptr = Pointer(Int32).malloc(1_u64)
        ptr2 = ptr.realloc(2)
        3
      CRYSTAL
    end

    it "interprets nilable pointer truthiness" do
      interpret(<<-CRYSTAL).should eq(1)
        ptr = 1 == 1 ? Pointer(UInt8).malloc(1) : nil
        if ptr
          1
        else
          2
        end
      CRYSTAL
    end
  end
end
