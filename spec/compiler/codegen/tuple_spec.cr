require "../../spec_helper"

describe "Code gen: tuple" do
  it "codegens tuple [0]" do
    run("{1, true}[0]").to_i.should eq(1)
  end

  it "codegens tuple [1]" do
    run("{1, true}[1]").to_b.should be_true
  end

  it "codegens tuple [1] (2)" do
    run("{true, 3}[1]").to_i.should eq(3)
  end

  it "codegens tuple [0]?" do
    run("{42, 'a'}[0]? || 84").to_i.should eq(42)
  end

  it "codegens tuple [1]?" do
    run("{'a', 42}[1]? || 84").to_i.should eq(42)
  end

  it "codegens tuple [2]?" do
    run("{'a', 42}[2]? || 84").to_i.should eq(84)
  end

  it "codegens tuple metaclass [0]" do
    run("Tuple(Int32, Char)[0].is_a?(Int32.class)").to_b.should be_true
  end

  it "codegens tuple metaclass [1]" do
    run("Tuple(Int32, Char)[1].is_a?(Char.class)").to_b.should be_true
  end

  it "codegens tuple metaclass [2]?" do
    run("Tuple(Int32, Char)[2]?.nil?").to_b.should be_true
  end

  it "codegens tuple [0..0]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[0..0]
      val.is_a?(Tuple(Int32)) && val[0] == 1
      CRYSTAL
  end

  it "codegens tuple [0..1]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[0..1]
      val.is_a?(Tuple(Int32, Bool)) && val[0] == 1 && val[1] == true
      CRYSTAL
  end

  it "codegens tuple [0..2]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[0..2]
      val.is_a?(Tuple(Int32, Bool)) && val[0] == 1&& val[1] == true
      CRYSTAL
  end

  it "codegens tuple [1..1]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[1..1]
      val.is_a?(Tuple(Bool)) && val[0] == true
      CRYSTAL
  end

  it "codegens tuple [1..0]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      def empty(*args)
        args
      end

      {1, true}[1..0].is_a?(typeof(empty))
      CRYSTAL
  end

  it "codegens tuple [2..2]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      def empty(*args)
        args
      end

      {1, true}[2..2].is_a?(typeof(empty))
      CRYSTAL
  end

  it "codegens tuple [0..0]?" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[0..0]?
      val.is_a?(Tuple(Int32)) && val[0] == 1
      CRYSTAL
  end

  it "codegens tuple [0..1]?" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[0..1]?
      val.is_a?(Tuple(Int32, Bool)) && val[0] == 1 && val[1] == true
      CRYSTAL
  end

  it "codegens tuple [0..2]?" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[0..2]?
      val.is_a?(Tuple(Int32, Bool)) && val[0] == 1&& val[1] == true
      CRYSTAL
  end

  it "codegens tuple [1..1]?" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      val = {1, true}[1..1]?
      val.is_a?(Tuple(Bool)) && val[0] == true
      CRYSTAL
  end

  it "codegens tuple [1..0]?" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      def empty(*args)
        args
      end

      {1, true}[1..0]?.is_a?(typeof(empty))
      CRYSTAL
  end

  it "codegens tuple [2..2]?" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      def empty(*args)
        args
      end

      {1, true}[2..2]?.is_a?(typeof(empty))
      CRYSTAL
  end

  it "codegens tuple [3..2]?" do
    run("#{range_new}; {1, true}[3..2]?.nil?").to_b.should be_true
  end

  it "codegens tuple [-3..2]?" do
    run("#{range_new}; {1, true}[-3..2]?.nil?").to_b.should be_true
  end

  it "codegens tuple metaclass [0..0]" do
    run("#{range_new}; Tuple(Int32, Char)[0..0].is_a?(Tuple(Int32).class)").to_b.should be_true
  end

  it "codegens tuple metaclass [0..1]" do
    run("#{range_new}; Tuple(Int32, Char)[0..1].is_a?(Tuple(Int32, Char).class)").to_b.should be_true
  end

  it "codegens tuple metaclass [1..0]" do
    run(<<-CRYSTAL).to_b.should be_true
      #{range_new}

      def empty(*args)
        args.class
      end

      Tuple(Int32, Char)[1..0].is_a?(typeof(empty))
      CRYSTAL
  end

  it "codegens tuple metaclass [3..2]?" do
    run("#{range_new}; Tuple(Int32, Char)[3..2]?.nil?").to_b.should be_true
  end

  it "codegens splats inside tuples" do
    run(<<-CRYSTAL).to_i.should eq(2 + 4 + 32 + 128)
      x = {1, *{2, 4}, 8, *{16, 32, 64}, 128}
      x[1] &+ x[2] &+ x[5] &+ x[7]
      CRYSTAL
  end

  it "passed tuple to def" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo(t)
        t[1]
      end

      foo({1, 2, 3})
      CRYSTAL
  end

  it "accesses T and creates instance from it" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct Tuple
        def type_args
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

      t = {Foo.new(1)}
      f = t.type_args[0].new(2)
      f.x
      CRYSTAL
  end

  it "allows malloc pointer of tuple" do
    run(<<-CRYSTAL).to_i.should eq(3)
      struct Pointer
        def self.malloc(size : Int)
          malloc(size.to_u64!)
        end
      end

      def foo(x : T) forall T
        p = Pointer(T).malloc(1)
        p.value = x
        p
      end

      p = foo({1, 2})
      p.value[0] &+ p.value[1]
      CRYSTAL
  end

  it "codegens tuple union (bug because union size was computed incorrectly)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"
      x = 1 == 1 ? {1, 1, 1} : {1}
      i = 2
      x[i]
      CRYSTAL
  end

  it "codegens tuple class" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar
      end

      foo = Foo.new(1)
      bar = Bar.new

      tuple = {foo, bar}
      tuple_class = tuple.class
      foo_class = tuple_class[0]
      foo2 = foo_class.new(2)
      foo2.x
      CRYSTAL
  end

  it "gets size at compile time" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct Tuple
        def my_size
          {{ T.size }}
        end
      end

      {1, 1}.my_size
      CRYSTAL
  end

  it "allows tuple covariance" do
    run(<<-CRYSTAL).to_i.should eq(42)
       class Obj
         def initialize
           @tuple = {Foo.new}
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
       obj.tuple = {Bar.new}
       obj.tuple[0].bar
       CRYSTAL
  end

  it "merges two tuple types of same size (1)" do
    run(<<-CRYSTAL).to_i.should eq(20)
       def foo
         if 1 == 2
           {"foo", 10}
         else
           {"foo", nil}
         end
       end

       val = foo[1]
       val || 20
       CRYSTAL
  end

  it "merges two tuple types of same size (2)" do
    run(<<-CRYSTAL).to_i.should eq(10)
       def foo
         if 1 == 1
           {"foo", 10}
         else
           {"foo", nil}
         end
       end

       val = foo[1]
       val || 20
       CRYSTAL
  end

  it "assigns tuple to compatible tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      ptr = Pointer({Int32 | String, Bool | Char}).malloc(1_u64)

      # Here the compiler should cast each value
      ptr.value = {42, 'x'}

      val = ptr.value[0]
      val.as?(Int32) || 10
      CRYSTAL
  end

  it "upcasts tuple inside compatible tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      def foo
        if 1 == 2
          {"hello", false}
        else
          {42, 'x'}
        end
      end

      val = foo[0]
      val.as?(Int32) || 10
      CRYSTAL
  end

  it "assigns tuple union to compatible tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      tup1 = {"hello", false}
      tup2 = {3}
      tup3 = {42, 'x'}

      ptr = Pointer(typeof(tup1, tup2, tup3)).malloc(1_u64)
      ptr.value = tup3
      val = ptr.value[0]
      val.as?(Int32) || 10
      CRYSTAL
  end

  it "upcasts tuple union to compatible tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      def foo
        if 1 == 2
          {"hello", false} || {3}
        else
          {42, 'x'}
        end
      end

      val = foo[0]
      val.as?(Int32) || 10
      CRYSTAL
  end

  it "assigns tuple inside union to union with compatible tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      tup1 = {"hello", false}
      tup2 = {3}

      union1 = tup1 || tup2

      tup3 = {42, 'x'}
      tup4 = {4}

      union2 = tup3 || tup4

      ptr = Pointer(typeof(union1, union2)).malloc(1_u64)
      ptr.value = union2
      val = ptr.value[0]
      val.as?(Int32) || 10
      CRYSTAL
  end

  it "upcasts tuple inside union to union with compatible tuple" do
    run(<<-CRYSTAL).to_i.should eq(42)
      def foo
        if 1 == 2
          tup1 = {"hello", false}
          tup2 = {3}
          union1 = tup1 || tup2
          union1
        else
          tup3 = {42, 'x'}
          tup4 = {4}
          union2 = tup3 || tup4
          union2
        end
      end

      val = foo[0]
      val.as?(Int32) || 10
      CRYSTAL
  end

  it "codegens union of tuple of float with tuple of tuple of float" do
    run(<<-CRYSTAL).to_i.should eq(42)
      a = {1.5}
      b = { {22.0, 20.0} }
      c = b || a
      v = c[0]
      if v.is_a?(Float64)
        10
      else
        v[0].to_i! &+ v[1].to_i!
      end
      CRYSTAL
  end

  it "provides T as a tuple literal" do
    run(<<-CRYSTAL).to_string.should eq("TupleLiteral")
      struct Tuple
        def self.foo
          {{ T.class_name }}
        end
      end
      Tuple(Nil, Int32).foo
      CRYSTAL
  end

  it "passes empty tuple and empty named tuple to a method (#2852)" do
    codegen(<<-CRYSTAL)
      def foo(*binds)
        baz(binds)
      end

      def bar(**binds)
        baz(binds)
      end

      def baz(binds)
        binds
      end

      foo
      bar
      CRYSTAL
  end

  it "assigns two same-size tuple types to a same var (#3132)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      t = {true}
      t
      t = {2}
      t[0]
      CRYSTAL
  end

  it "downcasts union to mixed tuple type" do
    run(<<-CRYSTAL).to_i.should eq(1)
      t = {1} || 2 || {true}
      t = {1}
      t[0]
      CRYSTAL
  end

  it "downcasts union to mixed union with mixed tuple types" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      t = {1} || 2 || {true}
      t = {1} || 2
      t.as(Tuple)[0]
      CRYSTAL
  end

  it "downcasts union inside tuple to value (#3907)" do
    codegen(<<-CRYSTAL)
      struct Foo
      end

      foo = Foo.new

      x = {0, foo}
      z = x[0]
      x = {0, z}
      CRYSTAL
  end
end

private def range_new
  %(
    struct Range(B, E)
      def initialize(@begin : B, @end : E, @exclusive : Bool = false)
      end
    end
  )
end
