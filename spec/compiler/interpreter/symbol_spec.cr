{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "symbol" do
    it "Symbol#to_s" do
      interpret(<<-CODE).should eq("hello")
        x = :hello
        x.to_s
      CODE
    end

    it "Symbol#to_i" do
      interpret(<<-CODE).should eq(0 + 1 + 2)
        x = :hello
        y = :bye
        z = :foo
        x.to_i + y.to_i + z.to_i
      CODE
    end

    it "symbol equality" do
      interpret(<<-CODE).should eq(9)
        s1 = :foo
        s2 = :bar

        a = 0
        a += 1 if s1 == s1
        a += 2 if s1 == s2
        a += 4 if s1 != s1
        a += 8 if s1 != s2
        a
      CODE
    end
  end
end
