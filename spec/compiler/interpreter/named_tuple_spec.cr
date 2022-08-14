{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "named tuple" do
    it "interprets named tuple literal and access by known index" do
      interpret(<<-CODE).should eq(6)
        a = {a: 1, b: 2, c: 3}
        a[:a] + a[:b] + a[:c]
      CODE
    end

    it "interprets named tuple metaclass indexer" do
      interpret(<<-CODE).should eq(2)
        struct Int32
          def self.foo
            2
          end
        end

        a = {a: 1, b: 'a'}
        a.class[:a].foo
      CODE
    end

    it "discards named tuple (#12383)" do
      interpret(<<-CODE).should eq(3)
        1 + ({a: 1, b: 2, c: 3, d: 4}; 2)
      CODE
    end
  end
end
