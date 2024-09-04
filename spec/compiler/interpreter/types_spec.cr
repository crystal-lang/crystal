{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "types" do
    it "interprets path to type" do
      context, repl_value = interpret_with_context("String")
      repl_value.value.should eq(context.program.string.metaclass)
    end

    it "interprets class for non-union type" do
      context, repl_value = interpret_with_context("1.class")
      repl_value.value.should eq(context.program.int32)
    end

    it "discards class for non-union type" do
      interpret("1.class; 2").should eq(2)
    end

    it "interprets class for virtual_type type" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("Bar"))
          class Foo; end
          class Bar < Foo; end

          bar = Bar.new || Foo.new
          bar.class.to_s
        CRYSTAL
    end

    it "interprets class for virtual_type type (struct)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("Baz"))
          abstract struct Foo; end
          struct Bar < Foo; end
          struct Baz < Foo; end

          baz = Baz.new || Bar.new
          baz.class.to_s
        CRYSTAL
    end

    it "does class method on virtual metaclass casted to generic metaclass (#12302)" do
      interpret(<<-CRYSTAL).should eq(42)
        class A
          def self.foo
            1
          end
        end

        class B(T) < A
          def self.foo
            42
          end
        end

        b = B(String).new.as(A)
        b.class.foo
      CRYSTAL
    end

    it "discards class for virtual_type type" do
      interpret(<<-CRYSTAL).should eq(2)
          class Foo; end
          class Bar < Foo; end

          bar = Bar.new || Foo.new
          bar.class
          2
        CRYSTAL
    end

    it "interprets class for module type (#12203)" do
      interpret(<<-CRYSTAL).should eq("A")
        class Class
          def name : String
            {{ @type.name.stringify }}
          end
        end

        module M
        end

        class E
          def initialize(@base : M)
          end
        end

        abstract class P
          include M
        end

        class A < P
        end

        e = E.new(A.new)
        base = e.@base
        base.class.name
        CRYSTAL
    end

    it "interprets crystal_type_id for nil" do
      interpret("nil.crystal_type_id").should eq(0)
    end

    it "interprets crystal_type_id for non-nil" do
      context, repl_value = interpret_with_context("1.crystal_type_id")
      repl_value.value.should eq(context.type_id(context.program.int32))
    end

    it "interprets crystal_type_id for virtual metaclass type (#12228)" do
      interpret(<<-CRYSTAL).should eq(true)
        class P
        end

        class A < P
        end

        p = A.as(P.class)
        p.crystal_type_id == A.crystal_type_id
        CRYSTAL
    end

    it "interprets class_crystal_instance_type_id" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("true")
        class Foo
        end

        Foo.new.crystal_type_id == Foo.crystal_instance_type_id
        CRYSTAL
    end

    it "discards Path" do
      interpret("String; 1").should eq(1)
    end

    it "discards typeof" do
      interpret("typeof(1); 1").should eq(1)
    end

    it "discards generic" do
      interpret("Pointer(Int32); 1").should eq(1)
    end

    it "discards .class" do
      interpret("1.class; 1").should eq(1)
    end

    it "discards crystal_type_id" do
      interpret("nil.crystal_type_id; 1").should eq(1)
    end
  end
end
