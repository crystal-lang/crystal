{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "constants" do
    it "returns nil in the assignment" do
      interpret(<<-CODE).should eq(nil)
        A = 123
      CODE
    end

    it "interprets constant literal" do
      interpret(<<-CODE).should eq(123)
        A = 123
        A
      CODE
    end

    it "interprets complex constant" do
      interpret(<<-CODE).should eq(6)
        A = begin
          a = 1
          b = 2
          a + b
        end
        A + A
      CODE
    end

    it "hoists constants" do
      interpret(<<-CODE).should eq(6)
        x = A + A

        A = begin
          a = 1
          b = 2
          a + b
        end

        x
      CODE
    end

    it "interprets self inside constant inside class" do
      interpret(<<-CODE).should eq(1)
        class Foo
          X = self.foo

          def self.foo
            bar
          end

          def self.bar
            1
          end
        end

        Foo::X
      CODE
    end
  end

  context "magic constants" do
    it "does line number" do
      interpret(<<-CODE).should eq(6)
          def foo(x, line = __LINE__)
            x + line
          end

          foo(1)
        CODE
    end
  end
end
