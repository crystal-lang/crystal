{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "sizeof" do
    it "interprets sizeof typeof" do
      interpret("sizeof(typeof(1))").should eq(4)
    end

    it "interprets sizeof Void" do
      interpret("sizeof(Void)").should eq(1)
    end

    it "interprets sizeof NoReturn" do
      interpret("sizeof(NoReturn)").should eq(0)
    end

    it "interprets sizeof Void expression" do
      interpret("sizeof(typeof((x = uninitialized Void)))").should eq(1)
    end

    it "interprets sizeof NoReturn expression" do
      interpret("sizeof(typeof((x = uninitialized NoReturn)))").should eq(0)
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

    it "interprets alignof Void" do
      interpret("alignof(Void)").should eq(1)
    end

    it "interprets alignof NoReturn" do
      interpret("alignof(NoReturn)").should eq(1)
    end

    it "interprets alignof Void expression" do
      interpret("alignof(typeof((x = uninitialized Void)))").should eq(1)
    end

    it "interprets alignof NoReturn expression" do
      interpret("alignof(typeof((x = uninitialized NoReturn)))").should eq(1)
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
