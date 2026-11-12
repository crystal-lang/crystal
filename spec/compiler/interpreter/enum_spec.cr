{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "enum" do
    it "does enum value" do
      interpret(<<-CRYSTAL).should eq(2)
        enum Color
          Red
          Green
          Blue
        end

        Color::Blue.value
      CRYSTAL
    end

    it "does enum new with a number literal autocast to its base type" do
      interpret(<<-CRYSTAL).should eq(7)
        enum Color : UInt128
          Red
        end

        color = Color.new(5)
        x = 2
        color.value.to_i32! + x
      CRYSTAL
    end

    it "does enum new" do
      interpret(<<-CRYSTAL).should eq(2)
        enum Color
          Red
          Green
          Blue
        end

        blue = Color.new(2)
        blue.value
      CRYSTAL
    end
  end
end
