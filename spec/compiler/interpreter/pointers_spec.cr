{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "pointers" do
    it "interprets pointer set and get (int)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 10
        ptr.value
      CODE
    end

    it "interprets pointer set and get (bool)" do
      interpret(<<-CODE).should be_true
        ptr = Pointer(Bool).malloc(1_u64)
        ptr.value = true
        ptr.value
      CODE
    end

    it "interprets pointer set and get (clear stack)" do
      interpret(<<-CODE).should eq(50.unsafe_chr)
        ptr = Pointer(UInt8).malloc(1_u64)
        ptr.value = 50_u8
        ptr.value.unsafe_chr
      CODE
    end

    it "interprets pointerof, mutates pointer, read var" do
      interpret(<<-CODE).should eq(2)
        a = 1
        ptr = pointerof(a)
        ptr.value = 2
        a
      CODE
    end

    it "interprets pointerof, mutates var, read pointer" do
      interpret(<<-CODE).should eq(2)
        a = 1
        ptr = pointerof(a)
        a = 2
        ptr.value
      CODE
    end

    it "interprets pointerof and mutates memory (there are more variables)" do
      interpret(<<-CODE).should eq(2)
        x = 42
        a = 1
        ptr = pointerof(a)
        ptr.value = 2
        a
      CODE
    end

    it "pointerof instance var" do
      interpret(<<-CODE).should eq(2)
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
      CODE
    end

    it "pointerof class var" do
      interpret(<<-CODE).should eq(2)
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
      CODE
    end

    it "pointerof read instance var" do
      interpret(<<-CODE).should eq(2)
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
      CODE
    end

    it "interprets pointer set and get (union type)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32 | Bool).malloc(1_u64)
        ptr.value = 10
        value = ptr.value
        if value.is_a?(Int32)
          value
        else
          20
        end
      CODE
    end

    it "interprets pointer set and get (union type, setter value)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32 | Bool).malloc(1_u64)
        ptr.value = 10
      CODE
    end

    it "interprets pointer new and pointer address" do
      interpret(<<-CODE).should eq(123_u64)
        ptr = Pointer(Int32 | Bool).new(123_u64)
        ptr.address
      CODE
    end

    it "interprets pointer diff" do
      interpret(<<-CODE).should eq(8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
      CODE
    end

    it "interprets pointer diff, negative" do
      interpret(<<-CODE).should eq(-8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr2 - ptr1
      CODE
    end

    it "discards pointer malloc" do
      interpret(<<-CODE).should eq(1)
        Pointer(Int32).malloc(1_u64)
        1
      CODE
    end

    it "discards pointer get" do
      interpret(<<-CODE).should eq(1)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value
        1
      CODE
    end

    it "discards pointer set" do
      interpret(<<-CODE).should eq(1)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 1
      CODE
    end

    it "discards pointer new" do
      interpret(<<-CODE).should eq(1)
        Pointer(Int32).new(1_u64)
        1
      CODE
    end

    it "discards pointer diff" do
      interpret(<<-CODE).should eq(1)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
        1
      CODE
    end

    it "discards pointerof" do
      interpret(<<-CODE).should eq(3)
        a = 1
        pointerof(a)
        3
      CODE
    end

    it "interprets pointer add" do
      interpret(<<-CODE).should eq(9)
        ptr = Pointer(Int32).new(1_u64)
        ptr2 = ptr + 2_i64
        ptr2.address
      CODE
    end

    it "discards pointer add" do
      interpret(<<-CODE).should eq(3)
        ptr = Pointer(Int32).new(1_u64)
        ptr + 2_i64
        3
      CODE
    end

    it "interprets pointer realloc" do
      interpret(<<-CODE).should eq(3)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr2 = ptr.realloc(2_u64)
        3
      CODE
    end

    it "discards pointer realloc" do
      interpret(<<-CODE).should eq(3)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.realloc(2_u64)
        3
      CODE
    end

    it "interprets pointer realloc wrapper" do
      interpret(<<-CODE).should eq(3)
        struct Pointer(T)
          def realloc(n)
            realloc(n.to_u64)
          end
        end

        ptr = Pointer(Int32).malloc(1_u64)
        ptr2 = ptr.realloc(2)
        3
      CODE
    end

    it "interprets nilable pointer truthiness" do
      interpret(<<-CODE).should eq(1)
        ptr = 1 == 1 ? Pointer(UInt8).malloc(1) : nil
        if ptr
          1
        else
          2
        end
      CODE
    end
  end
end
