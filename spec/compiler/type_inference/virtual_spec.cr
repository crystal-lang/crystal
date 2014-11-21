require "../../spec_helper"

describe "Type inference: virtual" do
  it "types two classes without a shared virtual" do
    assert_type("
      class Foo
      end

      class Bar
      end

      a = Foo.new || Bar.new
      ") { union_of(types["Foo"], types["Bar"]) }
  end

  it "types class and subclass as one type" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      ") { types["Foo"].virtual_type }
  end

  it "types two subclasses" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      ") { types["Foo"].virtual_type }
  end

  it "types class and two subclasses" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      ") { types["Foo"].virtual_type }
  end

  it "types method call of virtual type" do
    assert_type("
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      a.foo
      ") { int32 }
  end

  it "types method call of virtual type with override" do
    assert_type("
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
      ") { union_of(int32, float64) }
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
    result = infer_type nodes
    mod, nodes = result.program, result.node as Expressions
    (nodes.last as Call).target_defs.not_nil!.length.should eq(1)
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
    result = infer_type nodes
    mod, nodes = result.program, result.node as Expressions
    (nodes.last as Call).target_defs.not_nil!.length.should eq(2)
  end

  it "works with restriction alpha" do
    nodes = parse("
      require \"prelude\"

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
      ")
    infer_type nodes
  end

  it "doesn't check cover for subclasses" do
    assert_type("
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
      ") { union_of(int32, float64) }
  end

  it "removes instance var from subclasses" do
    nodes = parse "
      class Base
      end

      class Var < Base
        def x=(x)
          @x = x
        end
      end

      class Base
        def x=(x)
          @x = x
        end
      end

      v = Var.new
      v.x = 1
      v
      "
    result = infer_type nodes
    mod = result.program

    var = mod.types["Var"] as InstanceVarContainer
    var.instance_vars.length.should eq(0)

    base = mod.types["Base"] as InstanceVarContainer
    base.instance_vars["@x"].type.should eq(mod.union_of(mod.nil, mod.int32))
  end

  it "types inspect" do
    assert_type("
      require \"prelude\"

      class Foo
      end

      Foo.new.inspect
      ") { string }
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
    assert_type("
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
      ") { union_of(int32, float64) }
  end

  it "doesn't check methods on abstract classes 2" do
    assert_type("
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
      ") { union_of(int32, float64, char) }
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
    assert_type("
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
      ") { union_of(int32, float64, char) }
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
      "no overload matches"
  end

  it "checks cover in every concrete subclass" do
    assert_type("
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
      ") { |mod| mod.nil }
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
      "no overload matches"
  end

  it "checks cover in every concrete subclass 3" do
    assert_type("
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
      ") { |mod| mod.nil }
  end

  it "checks method in every concrete subclass but method in Object" do
    assert_type("
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
      ") { |mod| mod.nil }
  end

  # it "recalculates virtual type when subclass is added" do
  #   assert_type("
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
  #     ") { |mod| union_of(mod.nil, int32, char) }
  # end

  it "finds overloads of union of virtual, class and nil" do
    assert_type("
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
      ") { union_of(int32, float64) }
  end

  it "finds overloads of union of virtual, class and nil with abstract class" do
    assert_type("
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
      ") { union_of(int32, float64) }
  end

  it "restricts with union and doesn't merge to super type" do
    assert_type("
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
        \"hello\"
      end

      f = Bar.new || Baz.new || Bag.new
      foo(f)
      ") { union_of(int32, char, string) }
  end

  it "uses virtual type as generic type if class is abstract" do
    result = assert_type("
      abstract class Foo
      end

      class Bar(T)
      end

      Bar(Foo).new
      ") {
        foo = types["Foo"]
        bar = types["Bar"] as GenericClassType
        bar.instantiate([foo.virtual_type] of TypeVar)
      }
  end

  it "uses virtual type as generic type if class is abstract even in union" do
    result = assert_type("
      abstract class Foo
      end

      class Baz < Foo
      end

      class Bar(T)
      end

      Bar(Foo | Int32).new
      ") {
        foo = types["Foo"]
        bar = types["Bar"] as GenericClassType
        bar.instantiate([union_of(foo.virtual_type, int32)] of TypeVar)
      }
  end

  it "automatically does virtual for generic type if there are subclasses" do
    assert_type("
      class Foo; end
      class Bar < Foo; end

      Pointer(Foo).malloc(1_u64)
      ") { pointer_of(types["Foo"].virtual_type) }
  end
end
