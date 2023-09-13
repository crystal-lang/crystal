{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "casts" do
    it "casts from reference to pointer and back" do
      interpret(<<-CRYSTAL).should eq("hello")
        x = "hello"
        p = x.as(UInt8*)
        y = p.as(String)
        y
      CRYSTAL
    end

    it "casts from reference to nilable reference" do
      interpret(<<-CRYSTAL).should eq("hello")
        x = "hello"
        y = x.as(String | Nil)
        if y
          y
        else
          "bye"
        end
      CRYSTAL
    end

    it "casts from mixed union type to another mixed union type for caller" do
      interpret(<<-CRYSTAL).should eq(true)
        a = 1 == 1 ? 1 : (1 == 1 ? 20_i16 : nil)
        if a
          a < 2
        else
          false
        end
      CRYSTAL
    end

    it "casts from nilable type to mixed union type" do
      interpret(<<-CRYSTAL).should eq(2)
        ascii = true
        delimiter = 1 == 1 ? nil : "foo"

        if ascii && delimiter
          1
        else
          2
        end
        CRYSTAL
    end

    it "casts from nilable type to mixed union type (2)" do
      interpret(<<-CRYSTAL).should eq(true)
        y = 1 == 1 ? "a" : nil
        x = true
        x = y
        x.is_a?(String)
      CRYSTAL
    end

    it "casts from mixed union type to primitive type" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("2")
        x = 1 == 1 ? 2 : nil
        x.as(Int32)
      CRYSTAL
    end

    it "casts nilable from mixed union type to primitive type (non-nil case)" do
      interpret(<<-CRYSTAL).should eq(2)
        x = 1 == 1 ? 2 : nil
        y = x.as?(Int32)
        y ? y : 20
      CRYSTAL
    end

    it "casts nilable from mixed union type to primitive type (nil case)" do
      interpret(<<-CRYSTAL).should eq(20)
        x = 1 == 1 ? nil : 2
        y = x.as?(Int32)
        y ? y : 20
      CRYSTAL
    end

    it "upcasts between tuple types" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq((1 + 'a'.ord).to_s)
        a =
          if 1 == 1
            {1, 'a'}
          else
            {true, 3}
          end

        a[0].as(Int32) + a[1].as(Char).ord
      CRYSTAL
    end

    it "upcasts between named tuple types, same order" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq((1 + 'a'.ord).to_s)
        a =
          if 1 == 1
            {a: 1, b: 'a'}
          else
            {a: true, b: 3}
          end

        a[:a].as(Int32) + a[:b].as(Char).ord
      CRYSTAL
    end

    it "upcasts between named tuple types, different order" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq((1 + 'a'.ord).to_s)
        a =
          if 1 == 1
            {a: 1, b: 'a'}
          else
            {b:3, a: true}
          end

        a[:a].as(Int32) + a[:b].as(Char).ord
      CRYSTAL
    end

    it "upcasts to module type" do
      interpret(<<-CRYSTAL).should eq(1)
        module Moo
        end

        class Foo
          include Moo

          def foo
            1
          end
        end

        class Bar
          include Moo

          def foo
            2
          end
        end

        moo = (1 == 1 ? Foo.new : Bar.new).as(Moo)
        if moo.is_a?(Foo)
          moo.foo
        else
          10
        end
      CRYSTAL
    end

    it "upcasts virtual type to union" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          def foo
            1
          end
        end

        class Bar < Foo
          def foo
            2
          end
        end

        foo = 1 == 1 ? Bar.new : Foo.new
        a = 1 == 1 ? foo : 10
        if a.is_a?(Foo)
          a.foo
        else
          20
        end
      CRYSTAL
    end

    it "casts nil to Void*" do
      interpret(<<-CRYSTAL).should eq(0)
        module Moo
          def self.moo(r)
            r.as(Void*)
          end
        end

        Moo.moo(nil).address
      CRYSTAL
    end

    it "does is_a? with virtual metaclass" do
      interpret(<<-CRYSTAL).should eq(1)
        class A
          def self.a
            2
          end
        end

        class B < A
          def self.b
            1
          end
        end

        class C < B
        end

        x = B || A
        if x.is_a?(B.class)
          x.b
        elsif x.is_a?(A.class)
          x.a
        else
          0
        end
        CRYSTAL
    end

    it "discards cast" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("10")
        x = 1 || 'a'
        x.as(Int32)
        10
      CRYSTAL
    end

    it "raises when as fails" do
      interpret(<<-CRYSTAL, prelude: "prelude").to_s.should contain("Cast from Int32 to Char failed")
        x = 1 || 'a'
        begin
          x.as(Char)
          ""
        rescue ex : TypeCastError
          ex.message.not_nil!
        end
      CRYSTAL
    end

    it "casts to filtered type, not type in as(...)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("1")
        ({1} || 2).as(Tuple)[0]
      CRYSTAL
    end

    it "does is_a? with virtual type (struct)" do
      interpret(<<-CRYSTAL).should eq(10)
        abstract struct Foo
        end

        struct Bar < Foo
          def initialize(@x : Int32)
          end

          def bar
            @x
          end
        end

        struct Baz < Foo
          def initialize(@x : Int32)
          end

          def baz
            @x
          end
        end

        a = (Bar.new(10) || Baz.new(20)).as(Foo)
        case a
        when Bar
          a.bar
        when Baz
          a.baz
        else
          0
        end
        CRYSTAL
    end

    it "puts virtual metaclass into union (#12162)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("ActionA"))
        class Action
        end

        class ActionA < Action
        end

        class ActionB < Action
        end

        x = ActionA || ActionB
        y = x || Nil
        y.to_s
        CRYSTAL
    end

    it "puts tuple type inside union of different tuple type (#12243)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("{180}"))
        class A
          def initialize(@x : {Char | Int32}?)
          end

          def x
            @x
          end
        end

        x = A.new({180}).x
        x.to_s
      CRYSTAL
    end

    it "puts named tuple type inside union of different named tuple type (#12243)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("{v: 180}"))
        class A
          def initialize(@x : {v: Char | Int32}?)
          end

          def x
            @x
          end
        end

        x = A.new({v: 180}).x
        x.to_s
      CRYSTAL
    end

    it "casts from mixed union type to nilable proc type (#12283)" do
      interpret(<<-CRYSTAL).should eq("b")
        message = ->{ "b" }.as(String | Proc(String) | Nil)
        if message.is_a?(String)
          "a"
        elsif message.is_a?(Proc(String))
          message.call
        else
          "c"
        end
      CRYSTAL
    end

    it "does as? with no resulting type (#12327)" do
      interpret(<<-CRYSTAL).should eq(42)
        if nil.as?(Int32)
          0
        else
          42
        end
        CRYSTAL
    end

    it "does as? with no resulting type, not from nil (#12327)" do
      interpret(<<-CRYSTAL).should eq(42)
        if 1.as?(String)
          0
        else
          42
        end
        CRYSTAL
    end

    it "does as? with a type that can't match (#12346)" do
      interpret(<<-CRYSTAL).should eq(1)
        abstract class A
        end

        class B < A
        end

        class C < A
        end

        a = B.new || C.new
        a.as?(B | Int32) ? 1 : 2
        CRYSTAL
    end

    it "upcasts mixed union with tuple to mixed union with compatible tuple (1) (#12331)" do
      interpret(<<-CRYSTAL).should eq(1)
        class Foo
          def initialize(@tuple : Tuple(Int32?) | Tuple(Int32, Int32))
          end

          def tuple
            @tuple
          end
        end

        a = {1} || {1, 1}
        foo = Foo.new(a)
        tuple = foo.tuple
        if tuple.is_a?(Tuple(Int32?))
          value = tuple[0]
          if value
            value
          else
            2
          end
        else
          3
        end
      CRYSTAL
    end

    it "upcasts mixed union with tuple to mixed union with compatible tuple (2) (#12331)" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          def initialize(@tuple : Tuple(Int32?) | Tuple(Int32, Int32))
          end

          def tuple
            @tuple
          end
        end

        a = {nil} || {1, 1}
        foo = Foo.new(a)
        tuple = foo.tuple
        if tuple.is_a?(Tuple(Int32?))
          value = tuple[0]
          if value
            value
          else
            2
          end
        else
          3
        end
      CRYSTAL
    end

    it "upcasts mixed union with tuple to mixed union with compatible tuple (3) (#12331)" do
      interpret(<<-CRYSTAL).should eq(3)
        class Foo
          def initialize(@tuple : Tuple(Int32?) | Tuple(Int32, Int32))
          end

          def tuple
            @tuple
          end
        end

        a = {1, 1} || {1}
        foo = Foo.new(a)
        tuple = foo.tuple
        if tuple.is_a?(Tuple(Int32?))
          value = tuple[0]
          if value
            value
          else
            2
          end
        else
          3
        end
      CRYSTAL
    end

    it "upcasts in nilable cast (#12532)" do
      interpret(<<-CRYSTAL).should eq(2)
        struct Nil
          def foo
            0
          end
        end

        module A
          def foo
            1
          end
        end

        class B
          include A

          def foo
            2
          end
        end

        class C
          include A
        end

        B.new.as?(A).foo
        CRYSTAL
    end

    it "upcasts GenericClassInstanceMetaclassType to VirtualMetaclassType" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          def self.foo; 1; end
        end

        class Gen(T) < Foo
          def self.foo; 2; end
        end

        Gen(Int32).as(Foo.class).foo
        CRYSTAL
    end
  end
end
