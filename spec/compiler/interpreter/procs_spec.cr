{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "procs" do
    it "interprets no args proc literal" do
      interpret(<<-CRYSTAL).should eq(42)
        proc = ->{ 40 }
        proc.call + 2
      CRYSTAL
    end

    it "interprets proc literal with args" do
      interpret(<<-CRYSTAL).should eq(30)
        proc = ->(x : Int32, y : Int32) { x + y }
        proc.call(10, 20)
      CRYSTAL
    end

    it "interprets call inside Proc type" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Proc
          def call2
            call
          end
        end

        proc = ->{ 40 }
        proc.call2 + 2
      CRYSTAL
    end

    it "casts from nilable proc type to proc type" do
      interpret(<<-CRYSTAL).should eq(42)
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
      CRYSTAL
    end

    it "discards proc call" do
      interpret(<<-CRYSTAL).should eq(2)
        proc = ->{ 40 }
        proc.call
        2
      CRYSTAL
    end

    it "can downcast Proc(T) to Proc(Nil)" do
      interpret(<<-CRYSTAL)
        class Foo
          def initialize(@proc : ->)
          end

          def call
            @proc.call
          end
        end

        Foo.new(->{ 1 }).call
        CRYSTAL
    end
  end

  it "casts proc call arguments to proc arg types (#12350)" do
    interpret(<<-CRYSTAL).should eq(42)
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
    CRYSTAL
  end

  it "does call without receiver inside closure" do
    interpret(<<-CRYSTAL).should eq(42)
      struct Proc
        def foo
          ->{
            call
          }
        end
      end

      ->{ 42 }.foo.call
    CRYSTAL
  end

  it "calls proc primitive on union of module that has no subtypes (#12954)" do
    interpret(<<-CRYSTAL).should eq(42)
      module Test
      end

      proc = ->{ 42 }
      proc.as(Proc(Int32) | Test).call
    CRYSTAL
  end
end
