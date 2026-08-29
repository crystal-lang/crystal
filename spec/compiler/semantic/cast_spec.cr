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
    assert_error <<-CRYSTAL, "can't cast Pointer(Int32) to Foo(T)"
      class Foo(T)
      end

      a = 1
      pointerof(a).as(Foo)
      CRYSTAL
  end

  it "casts from union to compatible union" do
    assert_type("(1 || 1.5 || 'a').as(Int32 | Float64)") { union_of(int32, float64) }
  end

  it "casts to compatible type and use it" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "casts pointer of one type to another type" do
    assert_type(<<-CRYSTAL) { pointer_of(float64) }
      a = 1
      p = pointerof(a)
      p.as(Float64*)
      CRYSTAL
  end

  it "casts pointer to another type" do
    assert_type(<<-CRYSTAL) { types["String"] }
      a = 1
      p = pointerof(a)
      p.as(String)
      CRYSTAL
  end

  it "casts to module" do
    assert_type(<<-CRYSTAL) { union_of(types["Bar"].virtual_type, types["Baz"].virtual_type) }
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
      CRYSTAL
  end

  it "allows casting object to void pointer" do
    assert_type(<<-CRYSTAL) { pointer_of(void) }
      class Foo
      end

      Foo.new.as(Void*)
      CRYSTAL
  end

  it "allows casting reference union to void pointer" do
    assert_type(<<-CRYSTAL) { pointer_of(void) }
      class Foo
      end

      class Bar < Foo
      end

      foo = Foo.new || Bar.new
      foo.as(Void*)
      CRYSTAL
  end

  it "disallows casting int to pointer" do
    assert_error <<-CRYSTAL, "can't cast Int32 to Pointer(Void)"
      1.as(Void*)
      CRYSTAL
  end

  it "disallows casting fun to pointer" do
    assert_error <<-CRYSTAL, "can't cast Proc(Int32) to Pointer(Void)"
      f = ->{ 1 }
      f.as(Void*)
      CRYSTAL
  end

  it "disallows casting pointer to fun" do
    assert_error <<-CRYSTAL, "can't cast Pointer(Void) to Proc(Int32)"
      a = uninitialized Void*
      a.as(-> Int32)
      CRYSTAL
  end

  it "doesn't error if casting to a generic type" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", int32 }
      class Foo(T)
      end

      foo = Foo(Int32).new
      foo.as(Foo)
      CRYSTAL
  end

  it "casts to base class making it virtual (1)" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type! }
      class Foo
      end

      class Bar < Foo
      end

      Bar.new.as(Foo)
      CRYSTAL
  end

  it "casts to base class making it virtual (2)" do
    assert_type(<<-CRYSTAL) { union_of(int32, char) }
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
      CRYSTAL
  end

  it "casts to bigger union" do
    assert_type(<<-CRYSTAL) { union_of(int32, char) }
      1.as(Int32 | Char)
      CRYSTAL
  end

  it "errors on cast inside a call that can't be instantiated" do
    assert_error <<-CRYSTAL, "can't cast Int32 to Bool"
      def foo(x)
      end

      foo 1.as(Bool)
      CRYSTAL
  end

  it "casts to target type even if can't infer casted value type (obsolete)" do
    assert_type(<<-CRYSTAL) { array_of(int32) }
      require "prelude"

      class Foo
        property! x : Int32
      end

      a = [1, 2, 3]
      b = a.map { Foo.new.x.as(Int32) }

      Foo.new.x = 1
      b
      CRYSTAL
  end

  it "should error if can't cast even if not instantiated" do
    assert_error <<-CRYSTAL, "can't cast Foo to Bar"
      class Foo
      end

      class Bar < Foo
      end

      Foo.new.as(Bar)
      CRYSTAL
  end

  it "can cast to metaclass (bug)" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      Int32.as(Int32.class)
      CRYSTAL
  end

  it "can cast to metaclass (2) (#11121)" do
    assert_type(<<-CRYSTAL) { types["A"].virtual_type.metaclass }
      class A
      end

      class B < A
      end

      A.as(A.class)
      CRYSTAL
  end

  # Later we might want casting something to Object to have a meaning
  # similar to casting to Void*, but for now it's useless.
  it "disallows casting to Object (#815)" do
    assert_error <<-CRYSTAL, "can't cast to Object yet"
      nil.as(Object)
      CRYSTAL
  end

  it "doesn't allow upcast of generic type var (#996)" do
    assert_error <<-CRYSTAL, "can't cast Gen(Bar) to Gen(Foo)"
      class Foo
      end

      class Bar < Foo
      end

      class Gen(T)
      end

      Gen(Foo).new
      Gen(Bar).new.as(Gen(Foo))
      CRYSTAL
  end

  it "allows casting NoReturn to any type (#2132)" do
    assert_type(<<-CRYSTAL) { no_return }
      def foo
        foo
      end

      foo.as(Int32)
      CRYSTAL
  end

  it "errors if casting nil to Object inside typeof (#2403)" do
    assert_error <<-CRYSTAL, "can't cast to Object yet"
      require "prelude"

      puts(typeof(nil.as(Object)))
      CRYSTAL
  end

  it "disallows casting to Reference" do
    assert_error <<-CRYSTAL, "can't cast to Reference yet"
      "foo".as(Reference)
      CRYSTAL
  end

  it "disallows casting to Class" do
    assert_error <<-CRYSTAL, "can't cast to Class yet"
      nil.as(Class)
      CRYSTAL
  end

  it "can cast from Void* to virtual type (#3014)" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type! }
      abstract class Foo
      end

      class Bar < Foo
      end

      Bar.new.as(Void*).as(Foo)
      CRYSTAL
  end

  it "casts to generic virtual type" do
    assert_type(<<-CRYSTAL) { generic_class("Foo", int32).virtual_type! }
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      Bar(Int32).new.as(Foo(Int32))
      CRYSTAL
  end

  it "doesn't cast to virtual primitive (bug)" do
    assert_type(<<-CRYSTAL) { int32 }
      1.as(Int)
      CRYSTAL
  end

  it "doesn't crash with typeof no-type (#7441)" do
    assert_type(<<-CRYSTAL) { string }
      a = 1
      if a.is_a?(Char)
        1.as(typeof(a))
      else
        ""
      end
      CRYSTAL
  end

  it "doesn't cast to unbound generic type (as) (#5927)" do
    assert_error <<-CRYSTAL, "can't cast Int32 to Gen(T)"
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
      CRYSTAL
  end

  it "doesn't cast to unbound generic type (as?) (#5927)" do
    assert_type(<<-CRYSTAL) { nil_type }
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
      CRYSTAL
  end

  it "considers else to be unreachable (#9658)" do
    assert_type(<<-CRYSTAL) { int32 }
      case 1
      in Int32
        v = 1
      end
      v
      CRYSTAL
  end

  it "casts uninstantiated generic class to itself (#10882)" do
    assert_type(<<-CRYSTAL) { nilable types["Bar"] }
      class Foo
      end

      class Bar(T) < Foo
      end

      x = Foo.new.as(Foo)
      if x.is_a?(Bar)
        x.as(Bar)
      end
      CRYSTAL
  end

  it "doesn't eagerly try to check cast type (#12268)" do
    assert_type(<<-CRYSTAL) { int32 }
      bar = 1
      if bar.is_a?(Char)
        pointerof(bar).as(Pointer(typeof(bar)))
      else
        bar
      end
      CRYSTAL
  end
end
