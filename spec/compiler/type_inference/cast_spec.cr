require "../../spec_helper"

describe "Type inference: cast" do
  it "casts to same type is ok" do
    assert_type("1 as Int32 ") { int32 }
  end

  it "casts to incompatible type gives error" do
    assert_error "1 as Float64",
      "can't cast Int32 to Float64"
  end

  pending "casts from union to incompatible union gives error" do
    assert_error "(1 || 1.5) as Int32 | Char",
      "can't cast Int32 | Float64 to Int32 | Char"
  end

  it "casts from pointer to generic class gives error" do
    assert_error "
      class Foo(T)
      end

      a = 1
      pointerof(a) as Foo
      ",
      "can't cast Pointer(Int32) to Foo(T)"
  end

  it "casts from union to compatible union" do
    assert_type("(1 || 1.5 || 'a') as Int32 | Float64") { union_of(int32, float64) }
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
      b = a as Bar
      b.coco
    ") { int32 }
  end

  it "casts pointer of one type to another type" do
    assert_type("
      a = 1
      p = pointerof(a)
      p as Float64*
    ") { pointer_of(float64) }
  end

  it "casts pointer to another type" do
    assert_type("
      a = 1
      p = pointerof(a)
      p as String
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
      f as Moo
      ") { union_of(types["Bar"].virtual_type, types["Baz"].virtual_type) }
  end

  it "allows casting object to void pointer" do
    assert_type("
      class Foo
      end

      Foo.new as Void*
      ") { pointer_of(void) }
  end

  it "allows casting reference union to void pointer" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      foo = Foo.new || Bar.new
      foo as Void*
      ") { pointer_of(void) }
  end

  it "disallows casting int to pointer" do
    assert_error %(
      1 as Void*
      ),
      "can't cast Int32 to Pointer(Void)"
  end

  it "disallows casting fun to pointer" do
    assert_error %(
      f = ->{ 1 }
      f as Void*
      ),
      "can't cast ( -> Int32) to Pointer(Void)"
  end

  it "disallows casting pointer to fun" do
    assert_error %(
      a :: Void*
      a as -> Int32
      ),
      "can't cast Pointer(Void) to ( -> Int32)"
  end

  it "doesn't error if casting to a generic type" do
    assert_type(%(
      class Foo(T)
      end

      foo = Foo(Int32).new
      foo as Foo
      )) { (types["Foo"] as GenericClassType).instantiate([int32] of ASTNode | Type) }
  end

  it "casts to base class making it virtual (1)" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      Bar.new as Foo
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
      (bar as Foo).foo
      )) { union_of(int32, char) }
  end

  it "casts to bigger union" do
    assert_type(%(
      1 as Int32 | Char
      )) { union_of(int32, char) }
  end

  it "errors on cast inside a call that can't be instantiated" do
    assert_error %(
      def foo(x)
      end

      foo(1 as Bool)
      ),
      "can't cast Int32 to Bool"
  end

  it "casts to target type even if can't infer casted value type" do
    assert_type(%(
      require "prelude"

      class Foo
        property! x
      end

      a = [1, 2, 3]
      b = a.map { Foo.new.x as Int32 }

      Foo.new.x = 1
      b
      )) { array_of(int32) }
  end
end
