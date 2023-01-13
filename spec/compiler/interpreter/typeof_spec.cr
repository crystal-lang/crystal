{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "typeof" do
    it "interprets typeof instance type" do
      context, repl_value = interpret_with_context("typeof(1)")
      repl_value.value.should eq(context.program.int32.metaclass)
    end

    it "interprets typeof metaclass type" do
      context, repl_value = interpret_with_context("typeof(Int32)")
      repl_value.value.should eq(context.program.class_type)
    end

    it "interprets typeof virtual type" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("Foo"))
        abstract class Foo
        end

        class Bar < Foo
        end

        class Baz < Foo
        end

        foo = Baz.new.as(Foo)
        typeof(foo).to_s
      CRYSTAL
    end
  end
end
