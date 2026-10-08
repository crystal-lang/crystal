{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "named tuple" do
    it "interprets named tuple literal and access by known index" do
      interpret(<<-CRYSTAL).should eq(6)
        a = {a: 1, b: 2, c: 3}
        a[:a] + a[:b] + a[:c]
      CRYSTAL
    end

    it "interprets named tuple metaclass indexer" do
      interpret(<<-CRYSTAL).should eq(2)
        struct Int32
          def self.foo
            2
          end
        end

        a = {a: 1, b: 'a'}
        a.class[:a].foo
      CRYSTAL
    end

    it "downcasts a named tuple to one with narrower element types" do
      interpret(<<-CRYSTAL).should eq(3)
        def pick(flag : Bool) : Int32 | Char
          flag ? 1 : 'a'
        end

        a = {x: 'b', y: pick(true)}
        a = {x: 'c', y: 3}
        a[:y]
      CRYSTAL
    end

    it "downcasts a union to a named tuple with narrower element types than its member" do
      interpret(<<-CRYSTAL).should eq(3)
        def pick(flag : Bool) : Int32 | Char
          flag ? 1 : 'a'
        end

        a = 1 > 0 ? {x: 'b', y: pick(true)} : 5
        a = {x: 'c', y: 3}
        a[:y]
      CRYSTAL
    end

    it "downcasts a union to a smaller union with a named tuple with narrower element types" do
      interpret(<<-CRYSTAL).should eq(3)
        def pick(flag : Bool) : Int32 | Char
          flag ? 1 : 'a'
        end

        a = 1 > 2 ? 5 : (1 > 0 ? {x: pick(true)} : nil)
        a = 1 > 0 ? {x: 3} : nil
        if a
          a[:x]
        else
          0
        end
      CRYSTAL
    end

    it "calls a method on a variable that holds a named tuple with wider element types" do
      interpret(<<-CRYSTAL).should eq(3)
        struct NamedTuple
          def foo
            self[:x]
          end
        end

        def pick(flag : Bool) : Int32 | Char
          flag ? 1 : 'a'
        end

        a = {x: pick(true)}
        a = {x: 3}
        a.foo
      CRYSTAL
    end

    it "calls a method on a union variable that holds a named tuple with wider element types" do
      interpret(<<-CRYSTAL).should eq(3)
        struct NamedTuple
          def foo
            self[:x]
          end
        end

        struct Nil
          def foo
            0
          end
        end

        def pick(flag : Bool) : Int32 | Char
          flag ? 1 : 'a'
        end

        a = 1 > 0 ? {x: pick(true)} : nil
        a = 1 > 0 ? {x: 3} : nil
        a.foo
      CRYSTAL
    end

    it "discards named tuple (#12383)" do
      interpret(<<-CRYSTAL).should eq(3)
        1 + ({a: 1, b: 2, c: 3, d: 4}; 2)
      CRYSTAL
    end
  end
end
