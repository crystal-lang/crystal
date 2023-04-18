require "../../spec_helper"

describe "Semantic: cast" do
  it "casts to same type is ok" do
    assert_type("1.as(Int32)") { int32 }
  end

  it "casts to incompatible type gives error" do
    assert_error "1.as(Float64)",
      "can't cast Int32 to Float64"
  end

  pending "casts from union to incompatible union gives error" do
    assert_error "(1 || 1.5).as(Int32 | Char)",
      "can't cast Int32 | Float64 to Int32 | Char"
  end

  it "casts from pointer to generic class gives error" do
    assert_error "
      class Foo(T)
      end

      a = 1
      pointerof(a).as(Foo)
      ",
      "can't cast Pointer(Int32) to Foo(T)"
  end

  it "casts from union to compatible union" do
    assert_type("(1 || 1.5 || 'a').as(Int32 | Float64)") { union_of(int32, float64) }
  end

  it "casts to compatible type and use it" do
    assert_type("
      class Foo
      end

      class Bar < Foo
        def coco
          1
        end
      end

      a = Foo.new || Bar.new
      b = a.as(Bar)
      b.coco
    ") { int32 }
  end

  it "casts pointer of one type to another type" do
    assert_type("
      a = 1
      p = pointerof(a)
      p.as(Float64*)
    ") { pointer_of(float64) }
  end

  it "casts pointer to another type" do
    assert_type("
      a = 1
      p = pointerof(a)
      p.as(String)
    ") { types["String"] }
  end

  it "casts to module" do
    assert_type("
      module Moo
      end

      class Foo
      end

      class Bar < Foo
        include Moo
      end

      class Baz < Foo
        include Moo
      end

      f = Foo.new || Bar.new || Baz.new
      f.as(Moo)
      ") { union_of(types["Bar"].virtual_type, types["Baz"].virtual_type) }
  end

  it "allows casting object to void pointer" do
    assert_type("
      class Foo
      end

      Foo.new.as(Void*)
      ") { pointer_of(void) }
  end

  it "allows casting reference union to void pointer" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      foo = Foo.new || Bar.new
      foo.as(Void*)
      ") { pointer_of(void) }
  end

  it "disallows casting int to pointer" do
    assert_error %(
      1.as(Void*)
      ),
      "can't cast Int32 to Pointer(Void)"
  end

  it "disallows casting fun to pointer" do
    assert_error %(
      f = ->{ 1 }
      f.as(Void*)
      ),
      "can't cast Proc(Int32) to Pointer(Void)"
  end

  it "disallows casting pointer to fun" do
    assert_error %(
      a = uninitialized Void*
      a.as(-> Int32)
      ),
      "can't cast Pointer(Void) to Proc(Int32)"
  end

  it "doesn't error if casting to a generic type" do
    assert_type(%(
      class Foo(T)
      end

      foo = Foo(Int32).new
      foo.as(Foo)
      )) { generic_class "Foo", int32 }
  end

  it "casts to base class making it virtual (1)" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      Bar.new.as(Foo)
      )) { types["Foo"].virtual_type! }
  end

  it "casts to base class making it virtual (2)" do
    assert_type(%(
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          'a'
        end
      end

      bar = Bar.new
      bar.as(Foo).foo
      )) { union_of(int32, char) }
  end

  it "casts to bigger union" do
    assert_type(%(
      1.as(Int32 | Char)
      )) { union_of(int32, char) }
  end

  it "errors on cast inside a call that can't be instantiated" do
    assert_error %(
      def foo(x)
      end

      foo 1.as(Bool)
      ),
      "can't cast Int32 to Bool"
  end

  it "casts to target type even if can't infer casted value type (obsolete)" do
    assert_type(%(
      require "prelude"

      class Foo
        property! x : Int32
      end

      a = [1, 2, 3]
      b = a.map { Foo.new.x.as(Int32) }

      Foo.new.x = 1
      b
      )) { array_of(int32) }
  end

  it "should error if can't cast even if not instantiated" do
    assert_error %(
      class Foo
      end

      class Bar < Foo
      end

      Foo.new.as(Bar)
      ),
      "can't cast Foo to Bar"
  end

  it "can cast to metaclass (bug)" do
    assert_type(%(
      Int32.as(Int32.class)
      )) { int32.metaclass }
  end

  it "can cast to metaclass (2) (#11121)" do
    assert_type(%(
      class A
      end

      class B < A
      end

      A.as(A.class)
      )) { types["A"].virtual_type.metaclass }
  end

  # Later we might want casting something to Object to have a meaning
  # similar to casting to Void*, but for now it's useless.
  it "disallows casting to Object (#815)" do
    assert_error %(
      nil.as(Object)
      ),
      "can't cast to Object yet"
  end

  it "doesn't allow upcast of generic type var (#996)" do
    assert_error %(
      class Foo
      end

      class Bar < Foo
      end

      class Gen(T)
      end

      Gen(Foo).new
      Gen(Bar).new.as(Gen(Foo))
      ), "can't cast Gen(Bar) to Gen(Foo)"
  end

  it "allows casting NoReturn to any type (#2132)" do
    assert_type(%(
      def foo
        foo
      end

      foo.as(Int32)
      )) { no_return }
  end

  it "errors if casting nil to Object inside typeof (#2403)" do
    assert_error %(
      require "prelude"

      puts(typeof(nil.as(Object)))
      ),
      "can't cast to Object yet"
  end

  it "disallows casting to Reference" do
    assert_error %(
      "foo".as(Reference)
      ),
      "can't cast to Reference yet"
  end

  it "disallows casting to Class" do
    assert_error %(
      nil.as(Class)
      ),
      "can't cast to Class yet"
  end

  it "can cast from Void* to virtual type (#3014)" do
    assert_type(%(
      abstract class Foo
      end

      class Bar < Foo
      end

      Bar.new.as(Void*).as(Foo)
      )) { types["Foo"].virtual_type! }
  end

  it "casts to generic virtual type" do
    assert_type(%(
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      Bar(Int32).new.as(Foo(Int32))
      )) { generic_class("Foo", int32).virtual_type! }
  end

  it "doesn't cast to virtual primitive (bug)" do
    assert_type(%(
      1.as(Int)
      )) { int32 }
  end

  it "doesn't crash with typeof no-type (#7441)" do
    assert_type(%(
      a = 1
      if a.is_a?(Char)
        1.as(typeof(a))
      else
        ""
      end
      )) { string }
  end

  it "doesn't cast to unbound generic type (as) (#5927)" do
    assert_error %(
      class Gen(T)
        def foo
          sizeof(T)
        end
      end

      class Foo(I)
        def initialize(@x : Gen(I))
        end
      end

      Foo.new(Gen(Int32).new)

      1.as(Gen).foo
      ),
      "can't cast Int32 to Gen(T)"
  end

  it "doesn't cast to unbound generic type (as?) (#5927)" do
    assert_type(%(
      class Gen(T)
        def foo
          sizeof(T)
        end
      end

      class Foo(I)
        def initialize(@x : Gen(I))
        end
      end

      Foo.new(Gen(Int32).new)

      x = 1.as?(Gen)
      x.foo if x
      )) { nil_type }
  end

  it "considers else to be unreachable (#9658)" do
    assert_type(%(
      case 1
      in Int32
        v = 1
      end
      v
      )) { int32 }
  end

  it "casts uninstantiated generic class to itself (#10882)" do
    assert_type(%(
      class Foo
      end

      class Bar(T) < Foo
      end

      x = Foo.new.as(Foo)
      if x.is_a?(Bar)
        x.as(Bar)
      end
      )) { nilable types["Bar"] }
  end

  it "doesn't eagerly try to check cast type (#12268)" do
    assert_type(%(
      bar = 1
      if bar.is_a?(Char)
        pointerof(bar).as(Pointer(typeof(bar)))
      else
        bar
      end
      )) { int32 }
  end
end
