{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "tuple" do
    it "interprets tuple literal and access by known index" do
      interpret(<<-CRYSTAL).should eq(6)
        a = {1, 2, 3}
        a[0] + a[1] + a[2]
      CRYSTAL
    end

    it "interprets tuple range indexer" do
      interpret(<<-CRYSTAL).should eq(6)
        #{range_new}

        a = {1, 2, 4, 8, 16}
        b = a[1...-2]
        b[0] + b[1]
      CRYSTAL
    end

    it "interprets tuple range indexer (2)" do
      interpret(<<-CRYSTAL).should eq(24)
        #{range_new}

        a = {1_i8, 2_i8, 4_i8, 8_i8, 16_i32}
        b = a[3..]
        b[1] + b[0]
      CRYSTAL
    end

    it "interprets tuple literal of different types (1)" do
      interpret(<<-CRYSTAL).should eq(3)
        a = {1, true}
        a[0] + (a[1] ? 2 : 3)
      CRYSTAL
    end

    it "interprets tuple literal of different types (2)" do
      interpret(<<-CRYSTAL).should eq(3)
        a = {true, 1}
        a[1] + (a[0] ? 2 : 3)
      CRYSTAL
    end

    it "discards tuple access" do
      interpret(<<-CRYSTAL).should eq(1)
        foo = {1, 2}
        a = foo[0]
        foo[1]
        a
      CRYSTAL
    end

    it "interprets tuple self" do
      interpret(<<-CRYSTAL).should eq(6)
        struct Tuple
          def itself
            self
          end
        end

        a = {1, 2, 3}
        b = a.itself
        b[0] + b[1] + b[2]
      CRYSTAL
    end

    it "extends sign when doing to_i32" do
      interpret(<<-CRYSTAL).should eq(-50)
        t = {-50_i16}
        exp = t[0]
        z = exp.to_i32
        CRYSTAL
    end

    it "unpacks tuple in block arguments" do
      interpret(<<-CRYSTAL).should eq(6)
        def foo
          t = {1, 2, 3}
          yield t
        end

        foo do |x, y, z|
          x + y + z
        end
        CRYSTAL
    end

    it "interprets tuple metaclass indexer" do
      interpret(<<-CRYSTAL).should eq(2)
        struct Int32
          def self.foo
            2
          end
        end

        a = {1, 'a'}
        a.class[0].foo
      CRYSTAL
    end

    it "interprets tuple metaclass range indexer" do
      interpret(<<-CRYSTAL).should eq(3)
        #{range_new}

        struct Int32
          def self.foo
            1
          end
        end

        class String
          def self.bar
            2
          end
        end

        a = {true, 1, "a", 'a', 1.0}
        b = a.class[1...-2]
        b[0].foo + b[1].bar
      CRYSTAL
    end

    it "discards tuple (#12383)" do
      interpret(<<-CRYSTAL).should eq(3)
        1 + ({1, 2, 3, 4}; 2)
      CRYSTAL
    end

    it "does tuple indexer on union" do
      interpret(<<-CRYSTAL).should eq(1)
        module Test; end

        a = {1}
        a.as(Tuple(Int32) | Test)[0]
        CRYSTAL
    end
  end
end

private def range_new
  %(
    struct Range(B, E)
      def initialize(@begin : B, @end : E, @exclusive : Bool = false)
      end
    end
  )
end
