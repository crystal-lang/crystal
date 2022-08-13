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

    it "can downcast Proc(T) to Proc(Nil)" do
      interpret(<<-CODE)
        class Foo
          def initialize(@proc : ->)
          end

          def call
            @proc.call
          end
        end

        Foo.new(->{ 1 }).call
        CODE
    end
  end

  it "casts proc call arguments to proc arg types (#12350)" do
    interpret(<<-CODE).should eq(42)
      abstract struct Base
      end

      struct Foo < Base
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      struct Bar < Base
      end

      proc = ->(base : Base) {
        if base.is_a?(Foo)
          base.x
        else
          0
        end
      }

      bar = Foo.new(42)
      proc.call(bar)
    CODE
  end
end
