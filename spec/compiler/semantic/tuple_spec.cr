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

  it "types tuple with splats inside" do
    assert_type("{1, *{2.5, 'a'}, true}") { tuple_of([int32, float64, char, bool] of TypeVar) }
  end

  it "errors if non-tuple is splatted inside tuple" do
    assert_error "{*1}", "argument to splat must be a tuple, not Int32"
  end

  it "errors if non-tuple is splatted inside tuple (2)" do
    assert_error "{*{1} || {2, 3}}", "argument to splat must be a tuple, not (Tuple(Int32) | Tuple(Int32, Int32))"
  end

  describe "#[](NumberLiteral)" do
    it "types, inbound index" do
      assert_type("{1, 'a'}[0]") { int32 }
      assert_type("{1, 'a'}[1]") { char }

      assert_type("{1, 'a'}[-1]") { char }
      assert_type("{1, 'a'}[-2]") { int32 }
    end

    it "types, inbound index, nilable" do
      assert_type("{1, 'a'}[0]?") { int32 }
      assert_type("{1, 'a'}[1]?") { char }

      assert_type("{1, 'a'}[-1]?") { char }
      assert_type("{1, 'a'}[-2]?") { int32 }
    end

    it "types, out of bound, nilable" do
      assert_type("{1, 'a'}[2]?") { nil_type }
      assert_type("{1, 'a'}[-3]?") { nil_type }

      assert_type(<<-CRYSTAL) { nil_type }
        def tuple(*args)
          args
        end

        tuple()[0]?
        CRYSTAL
    end

    it "types, metaclass index" do
      assert_type("{1, 'a'}.class[0]", inject_primitives: true) { int32.metaclass }
      assert_type("{1, 'a'}.class[1]", inject_primitives: true) { char.metaclass }

      assert_type("{1, 'a'}.class[-1]", inject_primitives: true) { char.metaclass }
      assert_type("{1, 'a'}.class[-2]", inject_primitives: true) { int32.metaclass }
    end

    it "gives error when indexing out of range" do
      assert_error "{1, 'a'}[2]",
        "index out of bounds for Tuple(Int32, Char) (2 not in -2..1)"
    end

    it "gives error when indexing out of range on empty tuple" do
      assert_error <<-CRYSTAL, "index '0' out of bounds for empty tuple"
        def tuple(*args)
          args
        end

        tuple()[0]
        CRYSTAL
    end
  end

  describe "#[](RangeLiteral)" do
    it "types, inbound begin" do
      assert_type(%(#{range_new}; {1, 'a'}[0..-3])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[0..-2])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..-1])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..0])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..1])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..2])) { tuple_of([int32, char]) }

      assert_type(%(#{range_new}; {1, 'a'}[1..-3])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1..-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1..-1])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[1..0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1..1])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[1..2])) { tuple_of([char]) }

      assert_type(%(#{range_new}; {1, 'a'}[2..-3])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..-1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..2])) { tuple_of([] of Type) }

      assert_type(%(#{range_new}; {1, 'a'}[-1..-3])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..-1])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..1])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..2])) { tuple_of([char]) }

      assert_type(%(#{range_new}; {1, 'a'}[-2..-3])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..-2])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..-1])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..0])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..1])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..2])) { tuple_of([int32, char]) }

      assert_type(<<-CRYSTAL) { tuple_of([] of Type) }
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[0..0]
        CRYSTAL
    end

    it "types, inbound begin, end-less" do
      assert_type(%(#{range_new}; {1, 'a'}[0..])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[1..])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[2..])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..])) { tuple_of([int32, char]) }

      assert_type(<<-CRYSTAL) { tuple_of([] of Type) }
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[0..]
        CRYSTAL
    end

    it "types, begin-less" do
      assert_type(%(#{range_new}; {1, 'a'}[..0])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[..1])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[..2])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[..-3])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[..-2])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[..-1])) { tuple_of([int32, char]) }

      assert_type(<<-CRYSTAL) { tuple_of([] of Type) }
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[..0]
        CRYSTAL
    end

    it "types, begin-less, end-less" do
      assert_type(%(#{range_new}; {1, 'a'}[..])) { tuple_of([int32, char]) }

      assert_type(<<-CRYSTAL) { tuple_of([] of Type) }
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[..]
        CRYSTAL
    end

    it "types, exclusive range" do
      assert_type(%(#{range_new}; {1, 'a'}[0...-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[0...-1])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[0...0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[0...1])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[0...2])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[0...3])) { tuple_of([int32, char]) }

      assert_type(%(#{range_new}; {1, 'a'}[1...-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1...-1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1...0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1...1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1...2])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[1...3])) { tuple_of([char]) }

      assert_type(%(#{range_new}; {1, 'a'}[2...-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2...-1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2...0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2...1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2...2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2...3])) { tuple_of([] of Type) }

      assert_type(%(#{range_new}; {1, 'a'}[-1...-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1...-1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1...0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1...1])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1...2])) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-1...3])) { tuple_of([char]) }

      assert_type(%(#{range_new}; {1, 'a'}[-2...-2])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-2...-1])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2...0])) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-2...1])) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2...2])) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2...3])) { tuple_of([int32, char]) }
    end

    it "types, inbound begin, nilable" do
      assert_type(%(#{range_new}; {1, 'a'}[0..-3]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[0..-2]?)) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..-1]?)) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..0]?)) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..1]?)) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[0..2]?)) { tuple_of([int32, char]) }

      assert_type(%(#{range_new}; {1, 'a'}[1..-3]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1..-2]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1..-1]?)) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[1..0]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[1..1]?)) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[1..2]?)) { tuple_of([char]) }

      assert_type(%(#{range_new}; {1, 'a'}[2..-3]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..-2]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..-1]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..0]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..1]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[2..2]?)) { tuple_of([] of Type) }

      assert_type(%(#{range_new}; {1, 'a'}[-1..-3]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..-2]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..-1]?)) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..0]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..1]?)) { tuple_of([char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-1..2]?)) { tuple_of([char]) }

      assert_type(%(#{range_new}; {1, 'a'}[-2..-3]?)) { tuple_of([] of Type) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..-2]?)) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..-1]?)) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..0]?)) { tuple_of([int32]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..1]?)) { tuple_of([int32, char]) }
      assert_type(%(#{range_new}; {1, 'a'}[-2..2]?)) { tuple_of([int32, char]) }

      assert_type(<<-CRYSTAL) { tuple_of([] of Type) }
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[0..0]?
        CRYSTAL
    end

    it "types, out of bound begin, nilable" do
      assert_type(%(#{range_new}; {1, 'a'}[-3..0]?)) { nil_type }
      assert_type(%(#{range_new}; {1, 'a'}[3..2]?)) { nil_type }

      assert_type(<<-CRYSTAL) { nil_type }
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[1..0]?
        CRYSTAL
    end

    it "types, metaclass index" do
      assert_type(%(#{range_new}; {1, 'a'}.class[0..1]), inject_primitives: true) { tuple_of([int32, char]).metaclass }
      assert_type(%(#{range_new}; {1, 'a'}.class[1..2]), inject_primitives: true) { tuple_of([char]).metaclass }
      assert_type(%(#{range_new}; {1, 'a'}.class[1..-2]), inject_primitives: true) { tuple_of([] of Type).metaclass }
      assert_type(%(#{range_new}; {1, 'a'}.class[-2..-1]), inject_primitives: true) { tuple_of([int32, char]).metaclass }
      assert_type(%(#{range_new}; {1, 'a'}.class[-1..0]), inject_primitives: true) { tuple_of([] of Type).metaclass }
    end

    it "gives error when begin index is out of range" do
      assert_error <<-CRYSTAL, "begin index out of bounds for Tuple(Int32, Char) (3 not in -2..2)"
        #{range_new}

        {1, 'a'}[3..0]
        CRYSTAL

      assert_error <<-CRYSTAL, "begin index out of bounds for Tuple(Int32, Char) (-3 not in -2..2)"
        #{range_new}

        {1, 'a'}[-3..0]
        CRYSTAL

      assert_error <<-CRYSTAL, "begin index out of bounds for Tuple() (1 not in 0..0)"
        #{range_new}

        def tuple(*args)
          args
        end

        tuple()[1..0]
        CRYSTAL
    end
  end

  describe "#[](Path)" do
    it "works for tuple indexer" do
      assert_type("A = 0; {1, 'a'}[A]") { int32 }
    end

    it "works for named tuple indexer" do
      assert_type("A = :a; {a: 1, b: 'a'}[A]") { int32 }
    end
  end

  it "can name a tuple type" do
    assert_type("Tuple(Int32, Float64)") { tuple_of([int32, float64]).metaclass }
  end

  it "gives error when using named args on Tuple" do
    assert_error <<-CRYSTAL, "can only use named arguments with NamedTuple"
      Tuple(x: Int32, y: Char)
      CRYSTAL
  end

  it "doesn't error if Tuple has no args" do
    assert_type("Tuple()") { tuple_of([] of Type).metaclass }
  end

  it "types T as a tuple of metaclasses" do
    assert_type(<<-CRYSTAL
      struct Tuple
        def type_args
          T
        end
      end

      x = {1, 1.5, 'a'}
      x.type_args
      CRYSTAL
    ) do
      meta = tuple_of([int32, float64, char]).metaclass
      meta.metaclass?.should be_true
      meta
    end
  end

  it "errors on recursive splat expansion (#218)" do
    assert_error <<-CRYSTAL, "recursive splat expansion"
      def foo(*a)
        foo(a)
      end

      def foo(a : Tuple(String))
      end

      foo("a", "b")
      CRYSTAL
  end

  it "errors on recursive splat expansion (1) (#361)" do
    assert_error <<-CRYSTAL, "recursive splat expansion"
      require "prelude"

      def foo(type, *args)
        foo 1, args.to_a
      end

      foo "foo", 1
      CRYSTAL
  end

  it "errors on recursive splat expansion (2) (#361)" do
    assert_error <<-CRYSTAL, "recursive splat expansion"
      class Foo(T)
      end

      def foo(type, *args)
        foo 1, Foo(typeof(args)).new
      end

      foo "foo", 1
      CRYSTAL
  end

  it "doesn't trigger recursive splat expansion error (#7164)" do
    assert_no_errors %(
      def call(*args)
        call({1})
      end

      call(1)
      )
  end

  it "allows tuple covariance" do
    assert_type(<<-CRYSTAL) { tuple_of [types["Foo"].virtual_type!] }
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
      CRYSTAL
  end

  it "merges two tuple types of same size" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { tuple_of [string, nilable(int32)] }
      def foo
        if 1 == 2
          {"foo", 1}
        else
          {"foo", nil}
        end
      end

      foo
      CRYSTAL
  end

  it "accept tuple in type restriction" do
    assert_type(<<-CRYSTAL) { tuple_of [types["Bar"]] }
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : {Foo})
        x
      end

      foo({Bar.new})
      CRYSTAL
  end

  it "accepts tuple covariance in array" do
    assert_type(<<-CRYSTAL) { tuple_of [types["Foo"].virtual_type!, types["Foo"].virtual_type!] }
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      a = [] of {Foo, Foo}
      a << {Bar.new, Bar.new}
      a[0]
      CRYSTAL
  end

  it "can iterate T" do
    assert_type(<<-CRYSTAL) { tuple_of([int32.metaclass, string.metaclass]) }
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
      CRYSTAL
  end

  it "can call [] on T" do
    assert_type(<<-CRYSTAL) { nil_type.metaclass }
      struct Tuple
        def self.types
          {{ T[0] }}
        end
      end
      Tuple(Nil, Int32).types
      CRYSTAL
  end

  it "matches tuple with splat (#2932)" do
    assert_type(<<-CRYSTAL) { tuple_of([int32, char]).metaclass }
      def foo(x : Tuple(*T)) forall T
        T
      end

      foo({1, 'a'})
      CRYSTAL
  end

  it "matches tuple with splat (2) (#2932)" do
    assert_type(<<-CRYSTAL) { tuple_of([int32.metaclass, tuple_of([char, bool]).metaclass, float64.metaclass]) }
      def foo(x : Tuple(A, *B, C)) forall A, B, C
        {A, B, C}
      end

      foo({1, 'a', true, 1.5})
      CRYSTAL
  end

  it "errors if using two splat indices on restriction" do
    assert_error <<-CRYSTAL, "can't specify more than one splat in restriction"
      def foo(x : Tuple(*A, *B)) forall A, B
      end

      foo({1, 'a'})
      CRYSTAL
  end

  it "errors on tuple too big (#3816)" do
    assert_error <<-CRYSTAL, "tuple size cannot be greater than 300 (size is 302)"
      require "prelude"

      pos = {0, 0}
      while true
        pos += {0, 0}
      end
      CRYSTAL
  end

  it "errors on named tuple too big" do
    named_tuple_keys = String.build do |io|
      333.times { |i| io << "key" << i << ": 0, " }
    end

    assert_error <<-CRYSTAL, "named tuple size cannot be greater than 300 (size is 333)"
      { #{named_tuple_keys} }
      CRYSTAL
  end

  it "doesn't unify tuple metaclasses (#5384)" do
    assert_type(<<-CRYSTAL
      Tuple(Int32) || Tuple(String)
      CRYSTAL
    ) {
      union_of(
        tuple_of([int32] of Type).metaclass,
        tuple_of([string] of Type).metaclass,
      )
    }
  end

  it "doesn't crash on tuple in not executed block (#6718)" do
    assert_type(<<-CRYSTAL) { nil_type }
      require "prelude"

      def pending(&block)
      end

      def untyped(x = nil)
      end

      # To reproduce this bug, it is needed to the expression that is
      # not typed on main phase but is typed on cleanup phase.
      # `untyped(untyped)` is just one.
      pending do
        {untyped(untyped)}
      end
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
