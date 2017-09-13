require "../../spec_helper"

private macro expect_splat(e_arg, e_arg_index, e_obj, e_obj_index)
  arg.name.should eq({{e_arg}})
  arg_index.should eq({{e_arg_index}})
  obj.should eq({{e_obj}})
  obj_index.should eq({{e_obj_index}})
end

describe "Semantic: splat" do
  it "splats" do
    assert_type(%(
      def foo(*args)
        args
      end

      foo 1, 1.5, 'a'
      )) { tuple_of([int32, float64, char] of Type) }
  end

  it "errors on zero args with named arg and splat" do
    assert_error %(
      def foo(x, y = 1, *z)
      end

      foo
      ),
      "wrong number of arguments"
  end

  it "redefines method with splat (bug #248)" do
    assert_type(%(
      class Foo
        def bar(*x)
          1
        end
      end

      class Foo
        def bar(*x)
          'a'
        end
      end

      Foo.new.bar 1
      )) { char }
  end

  it "errors if splatting union" do
    assert_error %(
      a = {1} || {1, 2}
      foo *a
      ),
      "not yet supported"
  end

  it "errors if splatting non-tuple type" do
    assert_error %(
      foo *1
      ),
      "argument to splat must be a tuple, not Int32"
  end

  it "forwards tuple with an extra argument" do
    assert_type(%(
      def foo(*args)
        bar 1, *args
      end

      def bar(name, *args)
        args
      end

      x = foo 2
      x
      )) { tuple_of [int32] of TypeVar }
  end

  it "can splat after type filter left it as a tuple (#442)" do
    assert_type(%(
      def output(x, y)
        x + y
      end

      b = {1, 2} || nil
      if b
        output(*b)
      else
        4
      end
      )) { int32 }
  end

  it "errors if doesn't match splat with type restriction" do
    assert_error %(
      def foo(*args : Int32)
      end

      foo 1, 2, 3, 'a'
      ),
      "no overload matches"
  end

  it "works if matches splat with type restriction" do
    assert_type(%(
      def foo(*args : Int32)
        args[0]
      end

      foo 1, 2, 3
      )) { int32 }
  end

  it "overloads with type restriction and splat (1)" do
    assert_type(%(
      def foo(arg : Int32)
        1
      end

      def foo(*args : Int32)
        'a'
      end

      foo 1
      )) { int32 }
  end

  it "overloads with type restriction and splat (2)" do
    assert_type(%(
      def foo(arg : Int32)
        1
      end

      def foo(*args : Int32)
        'a'
      end

      foo 1, 2, 3
      )) { char }
  end

  it "errors if doesn't match splat with type restriction because of zero arguments" do
    assert_error %(
      def foo(*args : Int32)
      end

      foo
      ),
      "no overload matches"
  end

  it "overloads with type restriction and splat (3)" do
    assert_type(%(
      def foo(*args : Char)
        "hello"
      end

      def foo(*args : Int32)
        1.5
      end

      foo 'a', 'b', 'c'
      )) { string }
  end

  it "overloads with type restriction and splat (4)" do
    assert_type(%(
      def foo(*args : Char)
        "hello"
      end

      def foo(*args : Int32)
        1.5
      end

      foo 1, 2, 3
      )) { float64 }
  end

  it "overloads with type restriction and splat (5)" do
    assert_type(%(
      def foo(*args : Int32)
        "hello"
      end

      def foo
        1.5
      end

      foo 1, 2, 3
      )) { string }
  end

  it "overloads with type restriction and splat (6)" do
    assert_type(%(
      def foo(*args : Int32)
        "hello"
      end

      def foo
        1.5
      end

      foo
      )) { float64 }
  end

  it "overloads with type restriction and splat (7)" do
    assert_type(%(
      def foo(*args)
        foo args
      end

      def foo(args : Tuple)
        'a'
      end

      foo 1, 2, 3
      )) { char }
  end

  it "overloads with splat against method with two arguments (#986) (1)" do
    assert_type(%(
      def foo(a, b)
        1
      end

      def foo(*arg)
        'a'
      end

      foo "bar", "baz"
      )) { int32 }
  end

  it "overloads with splat against method with two arguments (#986) (2)" do
    assert_type(%(
      def foo(a, b)
        1
      end

      def foo(*arg)
        'a'
      end

      foo "bar"
      )) { char }
  end

  it "calls super with implicit splat arg (#1001)" do
    assert_type(%(
      class Foo
        def foo(name)
          name
        end
      end

      class Bar < Foo
        def foo(*args)
          super
        end
      end

      Bar.new.foo 1
      )) { int32 }
  end

  it "splats arg and splat against splat (1) (#1042)" do
    assert_type(%(
      def foo(a : Bool, *b : Int32)
        1
      end

      def foo(*b : Int32)
        'a'
      end

      foo(true, 3, 4, 5)
      )) { int32 }
  end

  it "splats arg and splat against splat (2) (#1042)" do
    assert_type(%(
      def foo(a : Bool, *b : Int32)
        1
      end

      def foo(*b : Int32)
        'a'
      end

      foo(3, 4, 5)
      )) { char }
  end

  it "gives correct error when forwarding splat" do
    assert_error %(
      def foo(x : Int)
      end

      def bar(*args)
        foo *args
      end

      bar 'a', 1
      ),
      "wrong number of arguments for 'foo' (given 2, expected 1)"
  end

  it "gives correct error when forwarding splat (2)" do
    assert_error %(
      def foo(x : Int, y : Int, z : Int, w : Int)
      end

      def bar(*args)
        foo 'a', *args
      end

      bar 1, "a", 1.7
      ),
      "no overload matches 'foo' with types Char, Int32, String, Float64"
  end

  it "doesn't crash on non-match (#2521)" do
    assert_error %(
      def test_func(a : String, *b, c, d)
      end

      if true
        val = ""
      end

      test_func(val, 1, 2, 3, 4, 5)
      ),
      "missing arguments: c, d"
  end

  it "says no overload matches on type restrictions past the splat arg" do
    assert_error %(
      def foo(*z, a : String, b : String)
      end

      foo(1, 2, 3, ("foo" || nil), ("bar" || nil))
      ),
      "missing arguments: a, b"
  end

  it "says missing argument because positional args don't match past splat" do
    assert_error %(
      def foo(x, *y, z)
      end

      foo 1, 2
      ),
      "missing argument: z"
  end

  it "allows default value after splat index" do
    assert_type(%(
      def foo(x, *y, z = 10)
        {x, y, z}
      end

      foo 'a', true, 1.5
      )) { tuple_of([char, tuple_of([bool, float64]), int32]) }
  end

  it "uses bare *" do
    assert_type(%(
      def foo(x, *, y)
        {x, y}
      end

      foo 10, y: 'a'
      )) { tuple_of([int32, char]) }
  end

  it "uses bare *, doesn't let more args" do
    assert_error %(
      def foo(x, *, y)
      end

      foo 10, 20, y: 30
      ),
      "no overload matches"
  end

  it "uses splat restriction" do
    assert_type(%(
      def foo(*args : *T) forall T
        T
      end

      foo 1, 'a', false
      )) { tuple_of([int32, char, bool]).metaclass }
  end

  it "uses splat restriction, matches empty" do
    assert_type(%(
      def foo(*args : *T) forall T
        T
      end

      foo
      )) { tuple_of([] of Type).metaclass }
  end

  it "uses splat restriction with concrete type" do
    assert_error %(
      struct Tuple(T)
        def self.foo(*args : *T)
        end
      end

      Tuple(Int32, Char).foo(1, true)
      ),
      "no overload matches"
  end

  it "method with splat and optional named argument matches zero args call (#2746)" do
    assert_type(%(
      def foo(*args, k1 = nil)
        args
      end

      foo
      )) { tuple_of([] of Type) }
  end

  it "method with default arguments and splat matches call with one arg (#2766)" do
    assert_type(%(
      def foo(a = nil, b = nil, *, c = nil)
        a
      end

      foo(10)
      )) { int32 }
  end

  it "accesses T when empty, via module" do
    assert_type(%(
      module Moo(T)
        def t
          T
        end
      end

      struct Tuple
        include Moo(Union(*T))

        def self.new(*args)
          args
        end
      end

      Tuple.new.t
      )) { no_return.metaclass }
  end

  it "matches splat in geneic type" do
    assert_type(%(
      class Foo(*T)
      end

      def method(x : Foo(A, *B, C)) forall A, B, C
        {A, B, C}
      end

      foo = Foo(Int32, Char, String, Bool).new
      method(foo)
      )) { tuple_of([int32.metaclass, tuple_of([char, string]).metaclass, bool.metaclass]) }
  end

  it "errors if using two splat indices on restriction" do
    assert_error %(
      class Foo(*T)
      end

      def method(x : Foo(A, *B, *C)) forall A, B, C
        {A, B, C}
      end

      foo = Foo(Int32, Char, String, Bool).new
      method(foo)
      ),
      "can't specify more than one splat in restriction"
  end

  it "matches with splat" do
    assert_type(%(
    def foo(&block : *{Int32, Int32} -> U) forall U
      tup = {1, 2}
      yield *tup
    end

    foo do |x, y|
      {x, y}
    end
    )) { tuple_of([int32, int32]) }
  end

  it "matches typed before non-typed (1) (#3134)" do
    assert_type(%(
      def bar(*args)
        "free"
      end

      def bar(*args : Int32)
        1
      end

      {bar(1, 2), bar('a', 1)}
      )) { tuple_of([int32, string]) }
  end

  it "matches typed before non-typed (1) (#3134)" do
    assert_type(%(
      def bar(*args : Int32)
        1
      end

      def bar(*args)
        "free"
      end

      {bar(1, 2), bar('a', 1)}
      )) { tuple_of([int32, string]) }
  end

  describe Splat do
    it "without splat" do
      a_def = Def.new("foo", args: [Arg.new("x"), Arg.new("y")])
      objs = [10, 20]

      i = 0
      Splat.before(a_def, objs) do |arg, arg_index, obj, obj_index|
        case i
        when 0
          expect_splat "x", 0, 10, 0
        when 1
          expect_splat "y", 1, 20, 1
        end
        i += 1
      end
      i.should eq(2)

      Splat.at(a_def, objs) do
        fail "expected at_splat not to invoke the block"
      end
    end

    it "with splat" do
      a_def = Def.new("foo", args: [Arg.new("a1"), Arg.new("a2"), Arg.new("a3"), Arg.new("a4")], splat_index: 2)
      objs = [10, 20, 30, 40, 50, 60]

      i = 0
      Splat.before(a_def, objs) do |arg, arg_index, obj, obj_index|
        case i
        when 0
          expect_splat "a1", 0, 10, 0
        when 1
          expect_splat "a2", 1, 20, 1
        end
        i += 1
      end
      i.should eq(2)

      i = 0
      Splat.at(a_def, objs) do |arg, arg_index, obj, obj_index|
        case i
        when 0
          expect_splat "a3", 2, 30, 2
        when 1
          expect_splat "a3", 2, 40, 3
        when 2
          expect_splat "a3", 2, 50, 4
        when 3
          expect_splat "a3", 2, 60, 5
        end
        i += 1
      end
      i.should eq(4)
    end
  end
end
