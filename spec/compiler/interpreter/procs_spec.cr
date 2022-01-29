{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "procs" do
    it "interprets no args proc literal" do
      interpret(<<-CODE).should eq(42)
        proc = ->{ 40 }
        proc.call + 2
      CODE
    end

    it "interprets proc literal with args" do
      interpret(<<-CODE).should eq(30)
        proc = ->(x : Int32, y : Int32) { x + y }
        proc.call(10, 20)
      CODE
    end

    it "interprets call inside Proc type" do
      interpret(<<-CODE).should eq(42)
        struct Proc
          def call2
            call
          end
        end

        proc = ->{ 40 }
        proc.call2 + 2
      CODE
    end

    it "casts from nilable proc type to proc type" do
      interpret(<<-CODE).should eq(42)
        proc =
          if 1 == 1
            ->{ 42 }
          else
            nil
          end

        if proc
          proc.call
        else
          1
        end
      CODE
    end

    it "discards proc call" do
      interpret(<<-CODE).should eq(2)
        proc = ->{ 40 }
        proc.call
        2
      CODE
    end
  end
end
