{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "tuple" do
    it "interprets tuple literal and access by known index" do
      interpret(<<-CODE).should eq(6)
        a = {1, 2, 3}
        a[0] + a[1] + a[2]
      CODE
    end

    it "interprets tuple range indexer" do
      interpret(<<-CODE).should eq(6)
        #{range_new}

        a = {1, 2, 4, 8, 16}
        b = a[1...-2]
        b[0] + b[1]
      CODE
    end

    it "interprets tuple range indexer (2)" do
      interpret(<<-CODE).should eq(24)
        #{range_new}

        a = {1_i8, 2_i8, 4_i8, 8_i8, 16_i32}
        b = a[3..]
        b[1] + b[0]
      CODE
    end

    it "interprets tuple literal of different types (1)" do
      interpret(<<-CODE).should eq(3)
        a = {1, true}
        a[0] + (a[1] ? 2 : 3)
      CODE
    end

    it "interprets tuple literal of different types (2)" do
      interpret(<<-CODE).should eq(3)
        a = {true, 1}
        a[1] + (a[0] ? 2 : 3)
      CODE
    end

    it "discards tuple access" do
      interpret(<<-CODE).should eq(1)
        foo = {1, 2}
        a = foo[0]
        foo[1]
        a
      CODE
    end

    it "interprets tuple self" do
      interpret(<<-CODE).should eq(6)
        struct Tuple
          def itself
            self
          end
        end

        a = {1, 2, 3}
        b = a.itself
        b[0] + b[1] + b[2]
      CODE
    end

    it "extends sign when doing to_i32" do
      interpret(<<-CODE).should eq(-50)
        t = {-50_i16}
        exp = t[0]
        z = exp.to_i32
        CODE
    end

    it "unpacks tuple in block arguments" do
      interpret(<<-CODE).should eq(6)
        def foo
          t = {1, 2, 3}
          yield t
        end

        foo do |x, y, z|
          x + y + z
        end
        CODE
    end

    it "interprets tuple metaclass indexer" do
      interpret(<<-CODE).should eq(2)
        struct Int32
          def self.foo
            2
          end
        end

        a = {1, 'a'}
        a.class[0].foo
      CODE
    end

    it "interprets tuple metaclass range indexer" do
      interpret(<<-CODE).should eq(3)
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
      CODE
    end

    it "discards tuple (#12383)" do
      interpret(<<-CODE).should eq(3)
        1 + ({1, 2, 3, 4}; 2)
      CODE
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
