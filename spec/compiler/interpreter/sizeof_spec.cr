{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "sizeof" do
    it "interprets sizeof typeof" do
      interpret("sizeof(typeof(1))").should eq(4)
    end
  end

  context "instance_sizeof" do
    it "interprets instance_sizeof typeof" do
      interpret(<<-CRYSTAL).should eq(16)
        class Foo
          @x = 0_i64
        end

        instance_sizeof(typeof(Foo.new))
        CRYSTAL
    end
  end

  context "alignof" do
    it "interprets alignof typeof" do
      interpret("alignof(typeof(1))").should eq(4)
    end
  end

  context "instance_alignof" do
    it "interprets instance_alignof typeof" do
      interpret(<<-CRYSTAL).should eq(8)
        class Foo
          @x = 0_i64
        end

        instance_alignof(typeof(Foo.new))
        CRYSTAL
    end
  end
end
