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
  end
end
