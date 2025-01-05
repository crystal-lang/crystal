{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "constants" do
    it "returns nil in the assignment" do
      interpret(<<-CRYSTAL).should eq(nil)
        A = 123
      CRYSTAL
    end

    it "interprets constant literal" do
      interpret(<<-CRYSTAL).should eq(123)
        A = 123
        A
      CRYSTAL
    end

    it "interprets complex constant" do
      interpret(<<-CRYSTAL).should eq(6)
        A = begin
          a = 1
          b = 2
          a + b
        end
        A + A
      CRYSTAL
    end

    it "hoists constants" do
      interpret(<<-CRYSTAL).should eq(6)
        x = A + A

        A = begin
          a = 1
          b = 2
          a + b
        end

        x
      CRYSTAL
    end

    it "interprets self inside constant inside class" do
      interpret(<<-CRYSTAL).should eq(1)
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
      CRYSTAL
    end
  end

  context "magic constants" do
    it "does line number" do
      interpret(<<-CRYSTAL).should eq(6)
          def foo(x, line = __LINE__)
            x + line
          end

          foo(1)
        CRYSTAL
    end
  end
end
