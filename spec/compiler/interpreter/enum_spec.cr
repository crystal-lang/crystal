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

    it "does enum with included module" do
      interpret(<<-CRYSTAL).should eq(3)
        module Moo
          def moo
            value &+ 1
          end
        end

        enum Color
          Red
          Green
          Blue

          include Moo
        end

        Color::Blue.moo
      CRYSTAL
    end
  end
end
