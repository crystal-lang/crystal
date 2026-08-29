require "../../spec_helper"

describe "Code gen: named tuple" do
  it "codegens tuple index" do
    run(<<-CRYSTAL).to_i.should eq(42)
      t = {x: 42, y: 'a'}
      t[:x]
      CRYSTAL
  end

  it "codegens tuple index another order" do
    run(<<-CRYSTAL).to_i.should eq(42)
      t = {y: 'a', x: 42}
      t[:x]
      CRYSTAL
  end

  it "codegens tuple nilable index (1)" do
    run(<<-CRYSTAL).to_i.should eq(42)
      t = {x: 42, y: 'a'}
      t[:x]? || 84
      CRYSTAL
  end

  it "codegens tuple nilable index (2)" do
    run(<<-CRYSTAL).to_i.should eq(42)
      t = {x: 'a', y: 42}
      t[:y]? || 84
      CRYSTAL
  end

  it "codegens tuple nilable index (3)" do
    run(<<-CRYSTAL).to_i.should eq(84)
      t = {x: 'a', y: 42}
      t[:z]? || 84
      CRYSTAL
  end

  it "passes named tuple to def" do
    run(<<-CRYSTAL).to_i.should eq(42)
      def foo(t)
        t[:x]
      end

      foo({y: 'a', x: 42})
      CRYSTAL
  end

  it "gets size at compile time" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct NamedTuple
        def my_size
          {{ T.size }}
        end
      end

      {x: 10, y: 20}.my_size
      CRYSTAL
  end

  it "gets keys at compile time (1)" do
    run(<<-CRYSTAL).to_string.should eq("x")
      struct NamedTuple
        def keys
          {{ T.keys.map(&.stringify)[0] }}
        end
      end

      {x: 10, y: 2}.keys
      CRYSTAL
  end

  it "gets keys at compile time (2)" do
    run(<<-CRYSTAL).to_string.should eq("y")
      struct NamedTuple
        def keys
          {{ T.keys.map(&.stringify)[1] }}
        end
      end

      {x: 10, y: 2}.keys
      CRYSTAL
  end

  it "doesn't crash when overload doesn't match" do
    codegen(<<-CRYSTAL)
      struct NamedTuple
        def foo(other : self)
        end

        def foo(other)
        end
      end

      tup1 = {a: 1}
      tup2 = {b: 1}
      tup1.foo(tup2)
      CRYSTAL
  end

  it "assigns named tuple to compatible named tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      ptr = Pointer({x: Int32, y: String}).malloc(1_u64)

      # Here the compiler should reorder the values to match
      # the type inside the pointer
      ptr.value = {y: "hello", x: 42}

      ptr.value[:x]
      CRYSTAL
  end

  it "upcasts named tuple inside compatible named tuple" do
    run(<<-CRYSTAL).to_string.should eq("Bar")
      def foo
        if 1 == 2
          {name: "Foo", age: 20}
        else
          # Here the compiler should reorder the values to match
          # those of the tuple above
          {age: 40, name: "Bar"}
        end
      end

      foo[:name]
      CRYSTAL
  end

  it "assigns named tuple union to compatible named tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      tup1 = {x: 1, y: "foo"}
      tup2 = {x: 3}
      tup3 = {y: "bar", x: 42}

      ptr = Pointer(typeof(tup1, tup2, tup3)).malloc(1_u64)

      # Here the compiler should reorder the values
      # inside tup3 to match the order of tup1
      ptr.value = tup3

      ptr.value[:x]
      CRYSTAL
  end

  it "upcasts named tuple union to compatible named tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      def foo
        if 1 == 2
          {x: 1, y: "foo"} || {x: 3}
        else
          {y: "bar", x: 42}
        end
      end

      foo[:x]
      CRYSTAL
  end

  it "assigns named tuple inside union to union with compatible named tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      tup1 = {x: 21, y: "foo"}
      tup2 = {x: 3}

      union1 = tup1 || tup2

      tup3 = {y: "bar", x: 42}
      tup4 = {x: 4}

      union2 = tup3 || tup4

      ptr = Pointer(typeof(union1, union2)).malloc(1_u64)

      # Here the compiler should reorder the values inside
      # tup3 inside union2 to match the order of tup1
      ptr.value = union2

      ptr.value[:x]
      CRYSTAL
  end

  it "upcasts named tuple inside union to union with compatible named tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      def foo
        if 1 == 2
          tup1 = {x: 21, y: "foo"}
          tup2 = {x: 3}
          union1 = tup1 || tup2
          union1
        else
          tup3 = {y: "bar", x: 42}
          tup4 = {x: 4}
          union2 = tup3 || tup4

          # Here the compiler should reorder the values inside
          # tup3 inside union2 to match the order of tup1
          union2
        end
      end

      foo[:x]
      CRYSTAL
  end

  it "allows named tuple covariance" do
    run(<<-CRYSTAL).to_i.should eq(42)
       class Obj
         def initialize
           @tuple = {foo: Foo.new}
         end

         def tuple=(@tuple)
         end

         def tuple
           @tuple
         end
       end

       class Foo
         def bar
           21
         end
       end

       class Bar < Foo
         def bar
           42
         end
       end

       obj = Obj.new
       obj.tuple = {foo: Bar.new}
       obj.tuple[:foo].bar
       CRYSTAL
  end

  it "merges two named tuple types with same keys but different types (1)" do
    run(<<-CRYSTAL).to_i.should eq(20)
       def foo
         if 1 == 2
           {x: "foo", y: 10}
         else
           {y: nil, x: "foo"}
         end
       end

       val = foo[:y]
       val || 20
       CRYSTAL
  end

  it "merges two named tuple types with same keys but different types (2)" do
    run(<<-CRYSTAL).to_i.should eq(10)
       def foo
         if 1 == 1
           {x: "foo", y: 10}
         else
           {y: nil, x: "foo"}
         end
       end

       val = foo[:y]
       val || 20
       CRYSTAL
  end

  it "codegens union of tuple of float with tuple of tuple of float" do
    run(<<-CRYSTAL).to_i.should eq(42)
      a = {x: 1.5}
      b = {x: {22.0, 20.0} }
      c = b || a
      v = c[:x]
      if v.is_a?(Float64)
        10
      else
        v[0].to_i! &+ v[1].to_i!
      end
      CRYSTAL
  end

  it "provides T as a named tuple literal" do
    run(<<-CRYSTAL).to_string.should eq("NamedTupleLiteral")
      struct NamedTuple
        def self.foo
          {{ T.class_name }}
        end
      end
      NamedTuple(x: Nil, y: Int32).foo
      CRYSTAL
  end

  it "assigns two same-size named tuple types to a same var (#3132)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      t = {x: true}
      t
      t = {x: 2}
      t[:x]
      CRYSTAL
  end

  it "downcasts union inside tuple to value (#3907)" do
    codegen(<<-CRYSTAL)
      struct Foo
      end

      foo = Foo.new

      x = {a: 0, b: foo}
      z = x[:a]
      x = {a: 0, b: z}
      CRYSTAL
  end

  it "accesses T and creates instance from it" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct NamedTuple
        def named_args
          T
        end
      end

      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      t = {a: Foo.new(1)}
      f = t.named_args[:a].new(2)
      f.x
      CRYSTAL
  end

  it "does to_s for NamedTuple class" do
    run(<<-CRYSTAL).to_string.should eq(%(NamedTuple(a: Int32, "b c": String, "+": Char)))
      require "prelude"

      NamedTuple(a: Int32, "b c": String, "+": Char).to_s
      CRYSTAL
  end

  it "doesn't error if NamedTuple includes a non-generic module (#10380)" do
    codegen(<<-CRYSTAL)
      module Foo
      end

      struct NamedTuple
        include Foo
      end

      x = uninitialized Foo
      x = {a: 1}
      CRYSTAL
  end
end
