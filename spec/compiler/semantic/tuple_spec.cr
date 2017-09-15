require "../../spec_helper"

describe "Semantic: tuples" do
  it "types tuple of one element" do
    assert_type("{1}") { tuple_of([int32] of TypeVar) }
  end

  it "types tuple of three elements" do
    assert_type("{1, 2.5, 'a'}") { tuple_of([int32, float64, char] of TypeVar) }
  end

  it "types tuple of one element and then two elements" do
    assert_type("{1}; {1, 2}") { tuple_of([int32, int32] of TypeVar) }
  end

  it "types tuple [0]" do
    assert_type("{1, 'a'}[0]") { int32 }
  end

  it "types tuple [1]" do
    assert_type("{1, 'a'}[1]") { char }
  end

  it "types tuple [-1]" do
    assert_type("{1, 'a'}[-1]") { char }
  end

  it "types tuple [-2]" do
    assert_type("{1, 'a'}[-2]") { int32 }
  end

  it "types tuple [0]?" do
    assert_type("{1, 'a'}[0]?") { int32 }
  end

  it "types tuple [1]?" do
    assert_type("{1, 'a'}[1]?") { char }
  end

  it "types tuple [2]?" do
    assert_type("{1, 'a'}[2]?") { nil_type }
  end

  it "types tuple [-1]?" do
    assert_type("{1, 'a'}[-1]?") { char }
  end

  it "types tuple [-2]?" do
    assert_type("{1, 'a'}[-2]?") { int32 }
  end

  it "types tuple [-3]?" do
    assert_type("{1, 'a'}[-3]?") { nil_type }
  end

  it "types tuple metaclass [0]" do
    assert_type("{1, 'a'}.class[0]") { int32.metaclass }
  end

  it "types tuple metaclass [1]" do
    assert_type("{1, 'a'}.class[1]") { char.metaclass }
  end

  it "types tuple metaclass [-1]" do
    assert_type("{1, 'a'}.class[-1]") { char.metaclass }
  end

  it "types tuple metaclass [-2]" do
    assert_type("{1, 'a'}.class[-2]") { int32.metaclass }
  end

  it "gives error when indexing out of range" do
    assert_error "{1, 'a'}[2]",
      "index out of bounds for Tuple(Int32, Char) (2 not in -2..1)"
  end

  it "gives error when indexing out of range on empty tuple" do
    assert_error %(
      def tuple(*args)
        args
      end

      tuple()[0]
      ),
      "index '0' out of bounds for empty tuple"
  end

  it "can name a tuple type" do
    assert_type("Tuple(Int32, Float64)") { tuple_of([int32, float64]).metaclass }
  end

  it "types T as a tuple of metaclasses" do
    assert_type("
      struct Tuple
        def type_args
          T
        end
      end

      x = {1, 1.5, 'a'}
      x.type_args
      ") do
      meta = tuple_of([int32, float64, char]).metaclass
      meta.metaclass?.should be_true
      meta
    end
  end

  it "errors on recursive splat expansion (#218)" do
    assert_error %(
      def foo(*a)
        foo(a)
      end

      def foo(a : Tuple(String))
      end

      foo("a", "b")
      ),
      "recursive splat expansion"
  end

  it "errors on recusrive splat expansion (1) (#361)" do
    assert_error %(
      require "prelude"

      def foo(type, *args)
        foo 1, args.to_a
      end

      foo "foo", 1
      ),
      "recursive splat expansion"
  end

  it "errors on recursive splat expansion (2) (#361)" do
    assert_error %(
      class Foo(T)
      end

      def foo(type, *args)
        foo 1, Foo(typeof(args)).new
      end

      foo "foo", 1
      ),
      "recursive splat expansion"
  end

  it "allows tuple covariance" do
    assert_type(%(
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
      end

      class Bar < Foo
      end

      obj = Obj.new
      obj.tuple = {Bar.new}
      obj.tuple
      )) { tuple_of [types["Foo"].virtual_type!] }
  end

  it "merges two tuple types of same size" do
    assert_type(%(
      def foo
        if 1 == 2
          {"foo", 1}
        else
          {"foo", nil}
        end
      end

      foo
      )) { tuple_of [string, nilable(int32)] }
  end

  it "accept tuple in type restriction" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : {Foo})
        x
      end

      foo({Bar.new})
      )) { tuple_of [types["Bar"]] }
  end

  it "accepts tuple covariance in array" do
    assert_type(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      a = [] of {Foo, Foo}
      a << {Bar.new, Bar.new}
      a[0]
      )) { tuple_of [types["Foo"].virtual_type!, types["Foo"].virtual_type!] }
  end

  it "can iterate T" do
    assert_type(%(
      struct Tuple
        def self.types
          {% begin %}
            {
              {% for type in T %}
                {{type}},
              {% end %}
            }
          {% end %}
        end
      end
      Tuple(Int32, String).types
      )) { tuple_of([int32.metaclass, string.metaclass]) }
  end

  it "can call [] on T" do
    assert_type(%(
      struct Tuple
        def self.types
          {{ T[0] }}
        end
      end
      Tuple(Nil, Int32).types
      )) { nil_type.metaclass }
  end

  it "matches tuple with splat (#2932)" do
    assert_type(%(
      def foo(x : Tuple(*T)) forall T
        T
      end

      foo({1, 'a'})
      )) { tuple_of([int32, char]).metaclass }
  end

  it "matches tuple with splat (2) (#2932)" do
    assert_type(%(
      def foo(x : Tuple(A, *B, C)) forall A, B, C
        {A, B, C}
      end

      foo({1, 'a', true, 1.5})
      )) { tuple_of([int32.metaclass, tuple_of([char, bool]).metaclass, float64.metaclass]) }
  end

  it "errors if using two splat indices on restriction" do
    assert_error %(
      def foo(x : Tuple(*A, *B)) forall A, B
      end

      foo({1, 'a'})
      ),
      "can't specify more than one splat in restriction"
  end

  it "errors on tuple too big (#3816)" do
    assert_error %(
      require "prelude"

      pos = {0, 0}
      while true
        pos += {0, 0}
      end
      ),
      "tuple too big"
  end
end
