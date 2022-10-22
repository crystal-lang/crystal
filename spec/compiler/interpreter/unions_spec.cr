{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "unions" do
    it "put and remove from union, together with is_a? (truthy case)" do
      interpret(<<-CODE).should eq(2)
        a = 1 == 1 ? 2 : true
        a.is_a?(Int32) ? a : 4
        CODE
    end

    it "put and remove from union, together with is_a? (falsey case)" do
      interpret(<<-CODE).should eq(true)
        a = 1 == 2 ? 2 : true
        a.is_a?(Int32) ? true : a
        CODE
    end

    it "returns union type" do
      interpret(<<-CODE).should eq('a')
        def foo
          if 1 == 1
            return 'a'
          end

          3
        end

        x = foo
        if x.is_a?(Char)
          x
        else
          'b'
        end
        CODE
    end

    it "put and remove from union in local var" do
      interpret(<<-CODE).should eq(3)
        a = 1 == 1 ? 2 : true
        a = 3
        a.is_a?(Int32) ? a : 4
        CODE
    end

    it "put and remove from union in instance var" do
      interpret(<<-CODE).should eq(2)
        class Foo
          @x : Int32 | Char

          def initialize
            if 1 == 1
              @x = 2
            else
              @x = 'a'
            end
          end

          def x
            @x
          end
        end

        foo = Foo.new
        z = foo.x
        if z.is_a?(Int32)
          z
        else
          10
        end
      CODE
    end

    it "discards is_a?" do
      interpret(<<-CODE).should eq(3)
        a = 1 == 1 ? 2 : true
        a.is_a?(Int32)
        3
        CODE
    end

    it "converts from NilableType to NonGenericClassType" do
      interpret(<<-CODE).should eq("a")
        a = 1 == 1 ? "a" : nil
        a || "b"
        CODE
    end

    it "puts union inside union" do
      interpret(<<-CODE).should eq('a'.ord)
        a = 'a' || 1 || true
        case a
        in Char
          a.ord
        in Int32
          a
        in Bool
          20
        end
        CODE
    end
  end
end
