{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

private def interpret_exception_flow(code)
  # Exercise real VM exception propagation without stdlib backtrace setup.
  interpret(<<-CRYSTAL + "\n" + code)
    @[Primitive(:interpreter_raise_without_backtrace)]
    def raise(exception : Exception) : NoReturn; end
    CRYSTAL
end

describe Crystal::Repl::Interpreter do
  context "exception handling" do
    it "does ensure without rescue/raise" do
      interpret(<<-CRYSTAL).should eq(12)
        x = 1
        y =
          begin
            10
          ensure
            x = 2
          end
        x + y
      CRYSTAL
    end

    it "does rescue when nothing is raised" do
      interpret(<<-CRYSTAL).should eq(1)
          a = begin
            1
          rescue
            'a'
          end

          if a.is_a?(Int32)
            a
          else
            10
          end
        CRYSTAL
    end

    it "raises and rescues anything" do
      interpret_exception_flow(<<-CRYSTAL).should eq(2)
          a = begin
            if 1 == 1
              raise Exception.new
            else
              'a'
            end
          rescue
            2
          end

          if a.is_a?(Int32)
            a
          else
            10
          end
        CRYSTAL
    end

    it "raises and rescues anything, does ensure when an exception is rescued" do
      interpret_exception_flow(<<-CRYSTAL).should eq(3)
          a = 0
          b = 0

          begin
            raise Exception.new
          rescue
            a = 1
          ensure
            b = 2
          end

          a + b
        CRYSTAL
    end

    it "raises and rescues specific exception type" do
      interpret_exception_flow(<<-CRYSTAL).should eq(2)
          class Ex1 < Exception; end
          class Ex2 < Exception; end

          a = 0

          begin
            raise Ex2.new
          rescue Ex1
            a = 1
          rescue Ex2
            a = 2
          end

          a
        CRYSTAL
    end

    it "captures exception in variable" do
      interpret_exception_flow(<<-CRYSTAL).should eq(10)
          class Ex1 < Exception
            def value; @value; end

            def initialize(@value : Int32)
            end
          end

          a = 0

          begin
            raise Ex1.new(10)
          rescue ex : Ex1
            a = ex.value
          end

          a
        CRYSTAL
    end

    it "executes ensure when exception is raised in body" do
      interpret_exception_flow(<<-CRYSTAL).should eq(10)
          a = 0

          begin
            begin
              raise Exception.new
            ensure
              a = 10
            end
          rescue
          end

          a
        CRYSTAL
    end

    it "executes ensure when exception is raised in rescue" do
      interpret_exception_flow(<<-CRYSTAL).should eq(10)
          a = 0

          begin
            begin
              raise Exception.new
            rescue
              raise Exception.new
            ensure
              a = 10
            end
          rescue
          end

          a
        CRYSTAL
    end

    it "does else" do
      interpret(<<-CRYSTAL).should eq(3)
          a =
            begin
              'a'
            rescue
              1
            else
              2
            end

          a + 1
        CRYSTAL
    end

    it "does ensure for else" do
      interpret(<<-CRYSTAL).should eq(2 + ((1 * 2) + 3))
          x = 1

          a =
            begin
              'a'
            rescue
              1
            else
              x *= 2
              2
            ensure
              x += 3
            end

          a + x
        CRYSTAL
    end

    it "does ensure for else when else raises" do
      interpret_exception_flow(<<-CRYSTAL).should eq(2)
          x = 1

          begin
            begin
              1
            rescue
              1
            else
              raise Exception.new
            ensure
              x += 1
            end
          rescue
          end

          x
        CRYSTAL
    end

    it "does ensure with explicit return" do
      interpret(<<-CRYSTAL).should eq(22)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def foo
          x = 1

          begin
            begin
              x += 1
              if x == 2
                return x
              end
            ensure
              Global.property = 10
            end
          ensure
            Global.property *= 2
          end

          0
        end

        x = foo
        Global.property + x
      CRYSTAL
    end

    it "executes ensure when returning from a block" do
      interpret(<<-CRYSTAL).should eq(21)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def foo
          block do
            return 1
          ensure
            Global.property = 10
          end

          0
        end

        x = foo
        Global.property + x
      CRYSTAL
    end

    it "executes ensure when returning from a block (2)" do
      interpret(<<-CRYSTAL).should eq(21)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def another_block
          yield
        end

        def something
          another_block do
            return
          end
        end

        def foo
          block do
            return 1
          ensure
            something
            Global.property = 10
          end

          0
        end

        x = foo
        Global.property + x
      CRYSTAL
    end

    it "executes ensure when breaking from a block" do
      interpret(<<-CRYSTAL).should eq(18)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def foo
          x = block do
            break 1
          ensure
            Global.property = 10
          end

          x - 3
        end

        x = foo
        Global.property + x
      CRYSTAL
    end

    it "executes ensure when returning a big value from a block" do
      (7 * sizeof(Int64)).should be > Crystal::Repl::Interpreter::SMALL_RETURN_VALUE_MAX_SIZE
      interpret(<<-CRYSTAL).should eq(41_i64)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def foo
          block do
            return {0_i64, 1_i64, 2_i64, 3_i64, 4_i64, 5_i64, 6_i64}
          ensure
            Global.property = 10
          end

          nil
        end

        x = foo
        if x
          Global.property &+ x[0] &+ x[1] &+ x[2] &+ x[3] &+ x[4] &+ x[5] &+ x[6]
        else
          0
        end
      CRYSTAL
    end
  end
end
