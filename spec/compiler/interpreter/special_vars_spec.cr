{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "special vars" do
    it "does special var that's a reference" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(x)
          $? = "hey"
        end

        foo(2)
        $? || "oops"
      CODE
    end

    it "does special var that's a struct" do
      interpret(<<-CODE).should eq(3)
        class Object; def not_nil!; self; end; end

        def foo(x)
          $? = 3
        end

        foo(2)
        $? || 4
      CODE
    end

    it "does special var that's a reference inside block" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def bar
          yield
        end

        def foo(x)
          bar do
            $? = "hey"
          end
        end

        foo(2)
        $? || "oops"
      CODE
    end

    it "does special var that's a reference when there are optional arguments" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(x = 1)
          $? = "hey"
        end

        foo
        $? || "oops"
      CODE
    end

    it "does special var that's a reference for multidispatch" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(x : Int32)
          $? = "hey"
        end

        def foo(x : String)
          $? = "ho"
        end

        a = 1 || "a"
        foo(a)
        $? || "oops"
      CODE
    end

    it "sets special var inside call inside block (#12250)" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo
          $? = "hey"
        end

        def bar
          yield
        end

        bar { foo }
        $? || "oops"
      CODE
    end
  end
end
