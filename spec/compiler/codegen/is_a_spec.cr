require "../../spec_helper"

describe "Codegen: is_a?" do
  it "codegens is_a? true for simple type" do
    run("1.is_a?(Int)").to_b.should be_true
  end

  it "codegens is_a? false for simple type" do
    run("1.is_a?(Bool)").to_b.should be_false
  end

  it "codegens is_a? with union gives true" do
    run("(1 == 1 ? 1 : 'a').is_a?(Int)").to_b.should be_true
  end

  it "codegens is_a? with union gives false" do
    run("(1 == 1 ? 1 : 'a').is_a?(Char)").to_b.should be_false
  end

  it "codegens is_a? with union gives false" do
    run("(1 == 1 ? 1 : 'a').is_a?(Float)").to_b.should be_false
  end

  it "codegens is_a? with union gives true" do
    run("(1 == 1 ? 1 : 'a').is_a?(Object)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives true" do
    run("(1 == 1 ? nil : Reference.new).is_a?(Nil)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false because other type 1" do
    run("(1 == 1 ? nil : Reference.new).is_a?(Reference)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false because other type 2" do
    run("(1 == 2 ? nil : Reference.new).is_a?(Reference)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false because no type" do
    run("(1 == 2 ? nil : Reference.new).is_a?(String)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false because no type" do
    run("1.is_a?(Object)").to_b.should be_true
  end

  it "evaluate method on filtered type" do
    run("a = 1; a = 'a'; if a.is_a?(Char); a.ord; else; 0; end").to_i.chr.should eq('a')
  end

  it "evaluate method on filtered type nilable type not-nil" do
    run("
      class Foo
        def foo
          1
        end
      end

      a = nil
      a = Foo.new
      if a.is_a?(Foo)
        a.foo
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "evaluate method on filtered type nilable type nil" do
    run("
      struct Nil
        def foo
          1
        end
      end

      class Foo
      end

      a = Foo.new
      a = nil
      if a.is_a?(Nil)
        a.foo
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "evaluates method on filtered union type" do
    run("
      class Foo
        def initialize(x : Int32)
          @x = x
        end

        def x
          @x
        end
      end

      a = 1
      a = Foo.new(2)

      if a.is_a?(Reference)
        a.x
      else
        0
      end
      ").to_i.should eq(2)
  end

  it "evaluates method on filtered union type 2" do
    run("
      class Foo
        def initialize(x : Int32)
          @x = x
        end

        def x
          @x
        end
      end

      class Bar
        def initialize(x : Int32)
          @x = x
        end

        def x
          @x
        end
      end

      a = 1
      a = Foo.new(2)
      a = Bar.new(3)

      if a.is_a?(Reference)
        a.x
      else
        0
      end
      ").to_i.should eq(3)
  end

  it "evaluates method on filtered union type 3" do
    run("
      require \"prelude\"
      a = 1
      a = [1.1]
      a = [5]

      if a.is_a?(Enumerable)
        a[0]
      else
        0
      end.to_i
    ").to_i.should eq(5)
  end

  it "codegens when is_a? is always false but properties are used" do
    run("
      require \"prelude\"

      class Foo
        def obj; 1 end
      end

      foo = 1
      foo.is_a?(Foo) && foo.obj && foo.obj
    ").to_b.should be_false
  end

  it "codegens is_a? on right side of and" do
    run("
      class Foo
        def bar
          true
        end
      end

      foo = Foo.new || nil
      if 1 == 1 && foo.is_a?(Foo) && foo.bar
        1
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "codegens is_a? with virtual" do
    run("
      class Foo
      end

      class Bar < Foo
      end

      foo = Bar.new || Foo.new
      foo.is_a?(Bar) ? 1 : 2
      ").to_i.should eq(1)
  end

  it "codegens is_a? with virtual and nil" do
    run("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new || nil
      f.is_a?(Foo) ? 1 : 2
      ").to_i.should eq(1)
  end

  it "codegens is_a? with virtual and module" do
    run("
      module Bar
      end

      abstract class FooBase2
      end

      abstract class FooBase < FooBase2
        include Bar
      end

      class Foo < FooBase
      end

      class Foo2 < FooBase2
      end

      f = Foo.new || Foo2.new
      f.is_a?(Bar)
      ").to_b.should be_true
  end

  it "restricts simple type with union" do
    run("
      a = 1
      if a.is_a?(Int32 | Char)
        a + 1
      else
        0
      end
      ").to_i.should eq(2)
  end

  it "restricts union with union" do
    run("
      struct Char
        def +(other : Int32)
          other
        end
      end

      struct Bool
        def foo
          2
        end
      end

      a = 1 || 'a' || false
      if a.is_a?(Int32 | Char)
        a + 2
      else
        a.foo
      end
      ").to_i.should eq(3)
  end

  it "codegens is_a? with a Const does comparison and gives true" do
    run("
      require \"prelude\"
      CONST = 1
      1.is_a?(CONST)
      ").to_b.should be_true
  end

  it "codegens is_a? with a Const does comparison and gives false" do
    run("
      require \"prelude\"
      CONST = 1
      2.is_a?(CONST)
      ").to_b.should be_false
  end

  it "gives false if generic type doesn't match exactly" do
    run("
      class Foo(T)
      end

      foo = Foo(Int32 | Float64).new
      foo.is_a?(Foo(Int32)) ? 1 : 2
      ").to_i.should eq(2)
  end

  it "does is_a? with more strict virtual type" do
    run("
      class Foo
      end

      class Bar < Foo
        def foo
          2
        end
      end

      f = Bar.new || Foo.new
      if f.is_a?(Bar)
        f.foo
      else
        1
      end
      ").to_i.should eq(2)
  end

  it "codegens is_a? casts union to nilable" do
    run("
      class Foo; end

      var = \"hello\" || Foo.new || nil
      if var.is_a?(Foo | Nil)
        var2 = var
        1
      else
        2
      end
      ").to_i.should eq(2)
  end

  it "codegens is_a? casts union to nilable in method" do
    run("
      class Foo; end

      def foo(var)
        if var.is_a?(Foo | Nil)
          var2 = var
          1
        else
          2
        end
      end

      var = \"hello\" || Foo.new || nil
      foo(var)
      ").to_i.should eq(2)
  end

  it "codegens is_a? from virtual type to module" do
    run("
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

      f = Bar.new || Baz.new
      if f.is_a?(Moo)
        g = f
        1
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "codegens is_a? from nilable reference union type to nil" do
    run("
      class Foo
      end

      class Bar
      end

      a = Foo.new || Bar.new || nil
      if a.is_a?(Nil)
        b = a
        1
      else
        2
      end
      ").to_i.should eq(2)
  end

  it "codegens is_a? from nilable reference union type to type" do
    run("
      class Foo
      end

      class Bar
      end

      a = Foo.new || Bar.new || nil
      if a.is_a?(Foo)
        b = a
        1
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "says false for value.is_a?(Class)" do
    run("
      1.is_a?(Class)
      ").to_b.should be_false
  end

  it "restricts type in else but lazily" do
    run("
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      foo = Foo.new(1)
      x = foo.x
      if x.is_a?(Int32)
        z = x + 1
      else
        z = x.foo_bar
      end

      z
      ").to_i.should eq(2)
  end

  it "works with inherited generic class against an instantiation" do
    run(%(
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      bar = Bar.new
      bar.is_a?(Foo(Int32))
      )).to_b.should be_true
  end

  it "works with inherited generic class against an instantiation (2)" do
    run(%(
      class Class1
      end

      class Class2 < Class1
      end

      class Foo(T)
      end

      class Bar < Foo(Class2)
      end

      bar = Bar.new
      bar.is_a?(Foo(Class1))
      )).to_b.should be_true
  end

  it "works with inherited generic class against an instantiation (3)" do
    run(%(
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      bar = Bar.new
      bar.is_a?(Foo(Float32))
      )).to_b.should be_false
  end

  it "doesn't type merge (1) (#548)" do
    run(%(
      class Base; end
      class Base1 < Base; end
      class Base2 < Base; end
      class Base3 < Base; end

      Base3.new.is_a?(Base1 | Base2)
      )).to_b.should be_false
  end

  it "doesn't type merge (2) (#548)" do
    run(%(
      class Base; end
      class Base1 < Base; end
      class Base2 < Base; end
      class Base3 < Base; end

      Base1.new.is_a?(Base1 | Base2) && Base2.new.is_a?(Base1 | Base2)
      )).to_b.should be_true
  end

  it "doesn't skip assignment when used in combination with .is_a? (true case, then) (#1121)" do
    run(%(
      a = 123
      if (b = a).is_a?(Int32)
        b + 1
      else
        a
      end
      )).to_i.should eq(124)
  end

  it "doesn't skip assignment when used in combination with .is_a? (true case, else) (#1121)" do
    run(%(
      a = 123
      if (b = a).is_a?(Int32)
        a + 2
      else
        b
      end
      )).to_i.should eq(125)
  end

  it "doesn't skip assignment when used in combination with .is_a? (false case) (#1121)" do
    run(%(
      a = 123
      if (b = a).is_a?(Char)
        b
      else
        b + 1
      end
      )).to_i.should eq(124)
  end

  it "doesn't skip assignment when used in combination with .is_a? and && (#1121)" do
    run(%(
      a = 123
      if (1 == 1) && (b = a).is_a?(Char)
        b
      else
        a
      end
      b ? b + 1 : 0
      )).to_i.should eq(124)
  end

  it "transforms then if condition is always truthy" do
    run(%(
      def foo
        123 && 456
      end

      if 1.is_a?(Int32)
        foo
      else
        999
      end
      )).to_i.should eq(456)
  end

  it "transforms else if condition is always falsey" do
    run(%(
      def foo
        123 && 456
      end

      if 1.is_a?(Char)
        999
      else
        foo
      end
      )).to_i.should eq(456)
  end

  it "resets truthy state after visiting nodes (bug)" do
    run(%(
      require "prelude"

      a = 123
      if !1.is_a?(Int32)
        a = 456
      end
      a
      )).to_i.should eq(123)
  end

  it "does is_a? with generic class metaclass" do
    run(%(
      class Foo(T)
      end

      Foo(Int32).is_a?(Foo.class)
      )).to_b.should be_true
  end

  it "says false for GenericChild(Base).is_a?(GenericBase(Child)) (#1294)" do
    run(%(
      class Base
      end

      class Child < Base
      end

      class GenericBase(T)
      end

      class GenericChild(T) < GenericBase(T)
      end

      GenericChild(Base).new.is_a?(GenericBase(Child))
      )).to_b.should be_false
  end

  it "does is_a?/responds_to? twice (#1451)" do
    run(%(
      a = 1 == 2 ? 1 : false
      if a.is_a?(Int32) && a.is_a?(Int32)
        3
      else
        4
      end
      )).to_i.should eq(4)
  end

  it "does is_a? with && and true condition" do
    run(%(
      a = 1 == 1 ? 1 : false
      if a.is_a?(Int32) && 1 == 1
        3
      else
        4
      end
      )).to_i.should eq(3)
  end

  it "does is_a? for union of module and type" do
    run(%(
      module Moo
        def moo
          2
        end
      end

      class Foo
        include Moo
      end

      class Bar
        include Moo
      end

      def foo(io)
        if io.is_a?(Moo)
          io.moo
        else
          3
        end
      end

      io = Foo.new.as(Moo) || 1
      foo(io)
      )).to_i.should eq(2)
  end

  it "does is_a? for virtual generic instance type against generic" do
    run(%(
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      def foo(x : Bar)
      end

      Bar(Int32).new.as(Foo(Int32)).is_a?(Bar) ? 2 : 3
      )).to_i.should eq(2)
  end

  it "doesn't consider generic type to be a generic type of a recursive alias (#3524)" do
    run(%(
      class Gen(T)
      end

      alias Type = Int32 | Gen(Type)
      a = Gen(Int32).new
      a.is_a?(Type)
      )).to_b.should be_false
  end

  it "codegens untyped var (#4009)" do
    codegen(%(
      require "prelude"

      i = 1
      1 || i.is_a?(Int32) ? "" : i
      ))
  end

  it "visits 1.to_s twice, may trigger enclosing_call (#4364)" do
    run(%(
      require "prelude"

      B = String
      1.to_s.is_a?(B)
      )).to_b.should be_true
  end

  it "says true for Class.is_a?(Class.class) (#4374)" do
    run("
      Class.is_a?(Class.class)
    ").to_b.should be_true
  end

  it "says true for Class.is_a?(Class.class.class) (#4374)" do
    run("
      Class.is_a?(Class.class.class)
    ").to_b.should be_true
  end
end
