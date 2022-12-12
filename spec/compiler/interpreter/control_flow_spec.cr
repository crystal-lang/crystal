{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "control flow" do
    it "interprets if (true literal)" do
      interpret("true ? 2 : 3").should eq(2)
    end

    it "interprets if (false literal)" do
      interpret("false ? 2 : 3").should eq(3)
    end

    it "interprets if (nil literal)" do
      interpret("nil ? 2 : 3").should eq(3)
    end

    it "interprets if bool (true)" do
      interpret("1 == 1 ? 2 : 3").should eq(2)
    end

    it "interprets if bool (false)" do
      interpret("1 == 2 ? 2 : 3").should eq(3)
    end

    it "interprets if (nil type)" do
      interpret("a = nil; a ? 2 : 3").should eq(3)
    end

    it "interprets if (int type)" do
      interpret("a = 1; a ? 2 : 3").should eq(2)
    end

    it "interprets if union type with bool, true" do
      interpret("a = 1 == 1 ? 1 : false; a ? 2 : 3").should eq(2)
    end

    it "interprets if union type with bool, false" do
      interpret("a = 1 == 2 ? 1 : false; a ? 2 : 3").should eq(3)
    end

    it "interprets if union type with nil, false" do
      interpret("a = 1 == 2 ? 1 : nil; a ? 2 : 3").should eq(3)
    end

    it "interprets if pointer, true" do
      interpret("ptr = Pointer(Int32).new(1_u64); ptr ? 2 : 3").should eq(2)
    end

    it "interprets if pointer, false" do
      interpret("ptr = Pointer(Int32).new(0_u64); ptr ? 2 : 3").should eq(3)
    end

    it "interprets unless" do
      interpret("unless 1 == 1; 2; else; 3; end").should eq(3)
    end

    it "discards if" do
      interpret("1 == 1 ? 2 : 3; 4").should eq(4)
    end

    it "interprets while" do
      interpret(<<-CRYSTAL).should eq(10)
        a = 0
        while a < 10
          a = a + 1
        end
        a
        CRYSTAL
    end

    it "interprets while, returns nil" do
      interpret(<<-CRYSTAL).should eq(nil)
        a = 0
        while a < 10
          a = a + 1
        end
        CRYSTAL
    end

    it "interprets until" do
      interpret(<<-CRYSTAL).should eq(10)
        a = 0
        until a == 10
          a = a + 1
        end
        a
      CRYSTAL
    end

    it "interprets break inside while" do
      interpret(<<-CRYSTAL).should eq(3)
        a = 0
        while a < 10
          a += 1
          break if a == 3
        end
        a
        CRYSTAL
    end

    it "interprets break inside nested while" do
      interpret(<<-CRYSTAL).should eq(6)
        a = 0
        b = 0
        c = 0

        while a < 3
          while b < 3
            b += 1
            c += 1
            break if b == 1
          end

          a += 1
          c += 1
          break if a == 3
        end

        c
        CRYSTAL
    end

    it "interprets break inside while inside block" do
      interpret(<<-CRYSTAL).should eq(3)
        def foo
          yield
          20
        end

        a = 0
        foo do
          while a < 10
            a += 1
            break if a == 3
          end
        end
        a
        CRYSTAL
    end

    it "interprets break with value inside while (through break)" do
      interpret(<<-CRYSTAL).should eq(8)
        a = 0
        x = while a < 10
          a += 1
          break 8 if a == 3
        end
        x || 10
        CRYSTAL
    end

    it "interprets break with value inside while (through normal flow)" do
      interpret(<<-CRYSTAL).should eq(10)
        a = 0
        x = while a < 10
          a += 1
          break 8 if a == 20
        end
        x || 10
        CRYSTAL
    end

    it "interprets next inside while" do
      interpret(<<-CRYSTAL).should eq(1 + 2 + 8 + 9 + 10)
        a = 0
        x = 0
        while a < 10
          a += 1

          next if 3 <= a <= 7

          x += a
        end
        x
        CRYSTAL
    end

    it "interprets next inside while inside block" do
      interpret(<<-CRYSTAL).should eq(1 + 2 + 8 + 9 + 10)
        def foo
          yield
          10
        end

        a = 0
        x = 0
        foo do
          while a < 10
            a += 1

            next if 3 <= a <= 7

            x += a
          end
        end
        x
        CRYSTAL
    end

    it "discards while" do
      interpret("while 1 == 2; 3; end; 4").should eq(4)
    end

    it "interprets return" do
      interpret(<<-CRYSTAL).should eq(2)
        def foo(x)
          if x == 1
            return 2
          end

          3
        end

        foo(1)
      CRYSTAL
    end

    it "interprets return Nil" do
      interpret(<<-CRYSTAL).should be_nil
        def foo : Nil
          1
        end

        foo
      CRYSTAL
    end

    it "interprets return Nil with explicit return (#12178)" do
      interpret(<<-CRYSTAL).should be_nil
        def foo : Nil
          return 1
        end

        foo
      CRYSTAL
    end

    it "interprets return implicit nil and Int32" do
      interpret(<<-CRYSTAL).should eq(10)
        def foo(x)
          if x == 1
            return
          end

          3
        end

        z = foo(1)
        if z.is_a?(Int32)
          z
        else
          10
        end
      CRYSTAL
    end
  end
end
