require "../../spec_helper"

describe "Semantic: named tuples" do
  it "types named tuple of one element" do
    assert_type("{x: 1}") { named_tuple_of({"x": int32}) }
  end

  it "types named tuple of two elements" do
    assert_type("{x: 1, y: 'a'}") { named_tuple_of({"x": int32, "y": char}) }
  end

  it "types named tuple of two elements, follows names order" do
    assert_type("{y: 'a', x: 1}") { named_tuple_of({"y": char, "x": int32}) }
  end

  it "types named tuple access (1)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t[:x]
      )) { int32 }
  end

  it "types named tuple access (2)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t[:y]
      )) { char }
  end

  it "types named tuple access (3)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t["x"]
      )) { int32 }
  end

  it "types named tuple access (4)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t["y"]
      )) { char }
  end

  it "types nilable named tuple access (1)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t[:x]?
      )) { int32 }
  end

  it "types nilable named tuple access (2)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t[:y]?
      )) { char }
  end

  it "types nilable named tuple access (3)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t[:foo]?
      )) { nil_type }
  end

  it "types nilable named tuple access (4)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t["x"]?
      )) { int32 }
  end

  it "types nilable named tuple access (5)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t["y"]?
      )) { char }
  end

  it "types nilable named tuple access (6)" do
    assert_type(%(
      t = {x: 1, y: 'a'}
      t["foo"]?
      )) { nil_type }
  end

  it "gives error when indexing with an unknown name" do
    assert_error "{x: 1, y: 'a'}[:z]",
      "missing key 'z' for named tuple NamedTuple(x: Int32, y: Char)"
  end

  it "can write generic type for NamedTuple" do
    assert_type(%(
      NamedTuple(x: Int32, y: Char)
      )) { named_tuple_of({"x": int32, "y": char}).metaclass }
  end

  it "gives error when using named args on a type other than NamedTuple" do
    assert_error %(
      class Foo(T)
      end

      Foo(x: Int32, y: Char)
      ),
      "can only use named arguments with NamedTuple"
  end

  it "gives error when using positional args with NamedTuple" do
    assert_error %(
      NamedTuple(Int32, Char)
      ),
      "can only instantiate NamedTuple with named arguments"
  end

  it "doesn't error if NamedTuple has no args" do
    assert_type("NamedTuple()") { named_tuple_of({} of String => Type).metaclass }
  end

  it "gets type at compile time" do
    assert_type(%(
      struct NamedTuple
        def y
          {{ T[:y] }}
        end
      end

      {x: 10, y: 'a'}.y
      )) { char.metaclass }
  end

  it "matches in type restriction" do
    assert_type(%(
      def foo(x : {x: Int32, y: Char})
        1
      end

      foo({x: 1, y: 'a'})
      )) { int32 }
  end

  it "matches in type restriction, different order (1)" do
    assert_type(%(
      def foo(x : {y: Char, x: Int32})
        1
      end

      foo({x: 1, y: 'a'})
      )) { int32 }
  end

  it "matches in type restriction, different order (2)" do
    assert_type(%(
      def foo(x : {x: Int32, y: Char})
        1
      end

      foo({y: 'a', x: 1})
      )) { int32 }
  end

  it "doesn't match in type restriction" do
    assert_error %(
      def foo(x : {x: Int32, y: Int32})
        1
      end

      foo({x: 1, y: 'a'})
      ),
      "expected argument #1 to 'foo' to be NamedTuple(x: Int32, y: Int32), not NamedTuple(x: Int32, y: Char)"
  end

  it "doesn't match type restriction with instance" do
    assert_error %(
      class Foo(T)
        def self.foo(x : T)
        end
      end

      Foo({a: Int32}).foo({a: 1.1})
      ),
      "expected argument #1 to 'Foo(NamedTuple(a: Int32)).foo' to be NamedTuple(a: Int32), not NamedTuple(a: Float64)"
  end

  it "matches in type restriction and gets free var" do
    assert_type(%(
      def foo(x : {x: T, y: T}) forall T
        T
      end

      foo({x: 1, y: 2})
      )) { int32.metaclass }
  end

  it "merges two named tuples with the same keys and types" do
    assert_type(%(
      t1 = {x: 1, y: 'a'}
      t2 = {y: 'a', x: 1}
      t1 || t2
      )) { named_tuple_of({"x": int32, "y": char}) }
  end

  it "can assign to union of compatible named tuple" do
    assert_type(%(
      tup1 = {x: 1, y: "foo"}
      tup2 = {x: 3}
      tup3 = {y: "bar", x: 2}

      ptr = Pointer(typeof(tup1, tup2, tup3)).malloc(1_u64)
      ptr.value = tup3
      ptr.value
      ), inject_primitives: true) { union_of(named_tuple_of({"x": int32}), named_tuple_of({"x": int32, "y": string})) }
  end

  it "allows tuple covariance" do
    assert_type(%(
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
      end

      class Bar < Foo
      end

      obj = Obj.new
      obj.tuple = {foo: Bar.new}
      obj.tuple
      )) { named_tuple_of({"foo": types["Foo"].virtual_type!}) }
  end

  it "merges two named tuple with same keys but different types" do
    assert_type(%(
      def foo
        if 1 == 2
          {x: "foo", y: 1}
        else
          {y: nil, x: 'a'}
        end
      end

      foo
      ), inject_primitives: true) { named_tuple_of({"x": union_of(char, string), "y": nilable(int32)}) }
  end

  it "accept named tuple in type restriction" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : {foo: Foo})
        x
      end

      foo({foo: Bar.new})
      )) { named_tuple_of({"foo": types["Bar"]}) }
  end

  it "accepts named tuple covariance in array" do
    assert_type(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      a = [] of {x: Foo, y: Foo}
      a << {x: Bar.new, y: Bar.new}
      a[0]
      )) { named_tuple_of({"x": types["Foo"].virtual_type!, "y": types["Foo"].virtual_type!}) }
  end

  it "types T as a tuple of metaclasses" do
    assert_type("
      struct NamedTuple
        def named_args
          T
        end
      end

      x = {a: 1, b: 1.5, c: 'a'}
      x.named_args
      ") do
      meta = named_tuple_of({"a": int32, "b": float64, "c": char}).metaclass
      meta.metaclass?.should be_true
      meta
    end
  end

  it "doesn't crash on named tuple in not executed block (#6718)" do
    assert_type(%(
      require "prelude"

      def pending(&block)
      end

      def untyped(x = nil)
      end

      # To reproduce this bug, it is needed to the expression that is
      # not typed on main phase but is typed on cleanup phase.
      # `untyped(untyped)` is just one.
      pending do
        {s: untyped(untyped)}
      end
    )) { nil_type }
  end

  it "doesn't crash on named tuple type recursion (#7162)" do
    assert_type(%(
      def call(*args)
        call({a: 1})
        1
      end

      call("")
      )) { int32 }
  end

  it "doesn't unify named tuple metaclasses (#5384)" do
    assert_type(%(
      NamedTuple(a: Int32) || NamedTuple(a: String)
      )) {
      union_of(
        named_tuple_of({"a": int32}).metaclass,
        named_tuple_of({"a": string}).metaclass,
      )
    }
  end
end
