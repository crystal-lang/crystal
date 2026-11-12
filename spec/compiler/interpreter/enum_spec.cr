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

    it "does enum value of a 128-bit enum inside its method" do
      interpret(<<-CRYSTAL).should eq(5)
        enum Color : UInt128
          Red

          def int_value
            value
          end
        end

        Color.new(5_u128).int_value.to_i32!
      CRYSTAL
    end
  end
end
