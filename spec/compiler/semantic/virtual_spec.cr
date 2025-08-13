require "../../spec_helper"

describe "Semantic: virtual" do
  it "types two classes without a shared virtual" do
    assert_type(<<-CRYSTAL) { union_of(types["Foo"], types["Bar"]) }
      class Foo
      end

      class Bar
      end

      a = Foo.new || Bar.new
      CRYSTAL
  end

  it "types class and subclass as one type" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      CRYSTAL
  end

  it "types two subclasses" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      CRYSTAL
  end

  it "types class and two subclasses" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      CRYSTAL
  end

  it "types method call of virtual type" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      a.foo
      CRYSTAL
  end

  it "types method call of virtual type with override" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64) }
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          1.5
        end
      end

      a = Foo.new || Bar.new
      a.foo
      CRYSTAL
  end

  it "dispatches virtual method" do
    nodes = parse("
      class Foo
        def foo
        end
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      x = Foo.new || Bar.new || Baz.new
      x.foo
      ")
    result = semantic nodes
    _, nodes = result.program, result.node.as(Expressions)
    nodes.last.as(Call).target_defs.not_nil!.size.should eq(1)
  end

  it "dispatches virtual method with overload" do
    nodes = parse("
      class Foo
        def foo
        end
      end

      class Bar < Foo
        def foo
        end
      end

      class Baz < Foo
      end

      x = Foo.new || Bar.new || Baz.new
      x.foo
      ")
    result = semantic nodes
    _, nodes = result.program, result.node.as(Expressions)
    nodes.last.as(Call).target_defs.not_nil!.size.should eq(2)
  end

  it "works with restriction alpha" do
    assert_no_errors <<-CRYSTAL
      require "prelude"

      class Foo
      end

      class Bar < Foo
        def foo
        end
      end

      class Baz < Bar
      end

      class Ban < Bar
      end

      a = [nil, Foo.new, Bar.new, Baz.new]
      a.push(Baz.new || Ban.new)
      CRYSTAL
  end

  it "doesn't check cover for subclasses" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64) }
      class Foo
        def foo(other)
          1
        end
      end

      class Bar < Foo
        def foo(other : Bar)
          1.5
        end
      end

      f = Foo.new || Bar.new
      x = f.foo(f)
      CRYSTAL
  end

  it "removes instance var from subclasses" do
    nodes = parse "
      class Base
      end

      class Var < Base
        def x=(x : Int32)
          @x = x
        end
      end

      class Base
        def x=(x : Int32)
          @x = x
        end
      end

      v = Var.new
      v.x = 1
      v
      "
    result = semantic nodes
    mod = result.program

    var = mod.types["Var"]
    var.instance_vars.size.should eq(0)

    base = mod.types["Base"]
    base.instance_vars["@x"].type.should eq(mod.nilable(mod.int32))
  end

  it "types inspect" do
    assert_type(<<-CRYSTAL) { string }
      require "prelude"

      class Foo
      end

      Foo.new.inspect
      CRYSTAL
  end

  it "reports no matches for virtual type" do
    assert_error "
      class Foo
      end

      class Bar < Foo
        def foo
        end
      end

      x = Foo.new || Bar.new
      x.foo
      ",
      "undefined method 'foo' for Foo"
  end

  it "doesn't check methods on abstract classes" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64) }
      abstract class Foo
      end

      class Bar1 < Foo
        def foo
          1
        end
      end

      class Bar2 < Foo
        def foo
          2.5
        end
      end

      f = Bar1.new || Bar2.new
      x = f.foo
      CRYSTAL
  end

  it "doesn't check methods on abstract classes 2" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64, char) }
      abstract class Foo
      end

      abstract class Bar < Foo
      end

      class Bar2 < Bar
        def foo
          1
        end
      end

      class Bar3 < Foo
        def foo
          2.5
        end
      end

      class Baz < Foo
        def foo
          'a'
        end
      end

      f = Bar2.new || Bar3.new || Baz.new
      x = f.foo
      CRYSTAL
  end

  it "reports undefined method in subclass of abstract class" do
    assert_error "
      abstract class Foo
      end

      abstract class Bar < Foo
      end

      class Bar2 < Bar
        def foo
          1
        end
      end

      class Bar3 < Bar
      end

      class Baz < Foo
        def foo
          'a'
        end
      end

      f = Bar2.new || Bar3.new || Baz.new
      x = f.foo
      ",
      "undefined method 'foo' for Bar3"
  end

  it "doesn't check cover for abstract classes" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64, char) }
      abstract class Foo
        def foo(other)
          1
        end
      end

      abstract class Bar < Foo
      end

      class Bar1 < Bar
      end

      class Bar2 < Bar
      end

      class Baz < Foo
      end

      def foo(other : Bar1)
        1
      end

      def foo(other : Bar2)
        2.5
      end

      def foo(other : Baz)
        'a'
      end

      f = Bar1.new || Bar2.new || Baz.new
      foo(f)
      CRYSTAL
  end

  it "reports missing cover for subclass of abstract class" do
    assert_error "
      abstract class Foo
        def foo(other)
          1
        end
      end

      abstract class Bar < Foo
      end

      class Bar1 < Bar
      end

      class Bar2 < Bar
      end

      class Baz < Foo
      end

      def foo(other : Bar1)
        1
      end

      def foo(other : Baz)
        'a'
      end

      f = Bar1.new || Bar2.new || Baz.new
      foo(f)
      ",
      "expected argument #1 to 'foo' to be Bar1 or Baz, not Foo"
  end

  it "checks cover in every concrete subclass" do
    assert_type(<<-CRYSTAL) { nil_type }
      abstract class Foo
      end

      abstract class Bar < Foo
      end

      class Bar1 < Bar
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      class Bar2 < Bar
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      class Baz < Foo
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      f = Bar1.new || Bar2.new || Baz.new
      f.foo(f)
      CRYSTAL
  end

  it "checks cover in every concrete subclass 2" do
    assert_error "
      abstract class Foo
      end

      abstract class Bar < Foo
      end

      class Bar1 < Bar
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      class Bar2 < Bar
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      class Baz < Foo
        def foo(x : Bar1); end
        def foo(x : Baz); end
      end

      f = Bar1.new || Bar2.new || Baz.new
      f.foo(f)
      ",
      "expected argument #1 to 'Baz#foo' to be Bar1 or Baz, not Foo"
  end

  it "checks cover in every concrete subclass 3" do
    assert_type(<<-CRYSTAL) { nil_type }
      abstract class Foo
      end

      abstract class Bar < Foo
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      class Bar1 < Bar
      end

      class Bar2 < Bar
      end

      class Baz < Foo
        def foo(x : Bar1); end
        def foo(x : Bar2); end
        def foo(x : Baz); end
      end

      f = Bar1.new || Bar2.new || Baz.new
      f.foo(f)
      CRYSTAL
  end

  it "checks method in every concrete subclass but method in Object" do
    assert_type(<<-CRYSTAL) { nil_type }
      class Object
        def foo
        end
      end

      abstract class Foo
      end

      class Bar1 < Foo
      end

      class Bar2 < Foo
      end

      f = Bar1.new || Bar2.new
      f.foo
      CRYSTAL
  end

  # it "recalculates virtual type when subclass is added" do
  #   assert_type(<<-CRYSTAL) { union_of(nil_type, int32, char) }
  #     class Foo
  #       def foo
  #         nil
  #       end
  #     end

  #     class Bar(T) < Foo
  #       def initialize(x : T)
  #         @x = x
  #       end

  #       def foo
  #         @x
  #       end
  #     end

  #     def coco(x)
  #       x.foo
  #     end

  #     a = Foo.new || Bar.new(1)
  #     b = coco(a)

  #     a2 = Foo.new || Bar.new('a')
  #     b2 = coco(a2)
  #     CRYSTAL
  # end

  it "finds overloads of union of virtual, class and nil" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64) }
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : Reference)
        1
      end

      def foo(x : Value)
        1.5
      end

      f = Foo.new || Bar.new || Reference.new || nil
      foo(f)
      CRYSTAL
  end

  it "finds overloads of union of virtual, class and nil with abstract class" do
    assert_type(<<-CRYSTAL) { union_of(int32, float64) }
      abstract class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      def foo(x : Reference)
        1
      end

      def foo(x : Value)
        1.5
      end

      f = Bar.new || Baz.new || Reference.new || nil
      foo(f)
      CRYSTAL
  end

  it "restricts with union and doesn't merge to super type" do
    assert_type(<<-CRYSTAL) { union_of(int32, char, string) }
      abstract class Foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Foo
        def foo
          'a'
        end
      end

      class Bag < Foo
      end

      def foo(x : Bar | Baz)
        x.foo
      end

      def foo(x)
        "hello"
      end

      f = Bar.new || Baz.new || Bag.new
      foo(f)
      CRYSTAL
  end

  it "uses virtual type as generic type if class is abstract" do
    assert_type(<<-CRYSTAL) { generic_class "Bar", types["Foo"].virtual_type }
      abstract class Foo
      end

      class Bar(T)
      end

      Bar(Foo).new
      CRYSTAL
  end

  it "uses virtual type as generic type if class is abstract even in union" do
    assert_type(<<-CRYSTAL) { generic_class "Bar", union_of(types["Foo"].virtual_type, int32) }
      abstract class Foo
      end

      class Baz < Foo
      end

      class Bar(T)
      end

      Bar(Foo | Int32).new
      CRYSTAL
  end

  it "automatically does virtual for generic type if there are subclasses" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { pointer_of(types["Foo"].virtual_type) }
      class Foo; end
      class Bar < Foo; end

      Pointer(Foo).malloc(1_u64)
      CRYSTAL
  end

  it "types instance var as virtual when using type declaration and has subclasses" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type! }
      class Foo
      end

      class Bar < Foo
        @foo : Foo

        def initialize
          @foo = Foo.new
        end

        def foo
          @foo
        end
      end

      Bar.new.foo
      CRYSTAL
  end
end
