require "../../spec_helper"

describe "Codegen: is_a?" do
  it "codegens is_a? true for simple type" do
    expect(run("1.is_a?(Int)").to_b).to be_true
  end

  it "codegens is_a? false for simple type" do
    expect(run("1.is_a?(Bool)").to_b).to be_false
  end

  it "codegens is_a? with union gives true" do
    expect(run("(1 == 1 ? 1 : 'a').is_a?(Int)").to_b).to be_true
  end

  it "codegens is_a? with union gives false" do
    expect(run("(1 == 1 ? 1 : 'a').is_a?(Char)").to_b).to be_false
  end

  it "codegens is_a? with union gives false" do
    expect(run("(1 == 1 ? 1 : 'a').is_a?(Float)").to_b).to be_false
  end

  it "codegens is_a? with union gives true" do
    expect(run("(1 == 1 ? 1 : 'a').is_a?(Object)").to_b).to be_true
  end

  it "codegens is_a? with nilable gives true" do
    expect(run("(1 == 1 ? nil : Reference.new).is_a?(Nil)").to_b).to be_true
  end

  it "codegens is_a? with nilable gives false becuase other type 1" do
    expect(run("(1 == 1 ? nil : Reference.new).is_a?(Reference)").to_b).to be_false
  end

  it "codegens is_a? with nilable gives false becuase other type 2" do
    expect(run("(1 == 2 ? nil : Reference.new).is_a?(Reference)").to_b).to be_true
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    expect(run("(1 == 2 ? nil : Reference.new).is_a?(String)").to_b).to be_false
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    expect(run("1.is_a?(Object)").to_b).to be_true
  end

  it "evaluate method on filtered type" do
    expect(run("a = 1; a = 'a'; if a.is_a?(Char); a.ord; else; 0; end").to_i.chr).to eq('a')
  end

  it "evaluate method on filtered type nilable type not-nil" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "evaluate method on filtered type nilable type nil" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "evaluates method on filtered union type" do
    expect(run("
      class Foo
        def initialize(x)
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
      ").to_i).to eq(2)
  end

  it "evaluates method on filtered union type 2" do
    expect(run("
      class Foo
        def initialize(x)
          @x = x
        end

        def x
          @x
        end
      end

      class Bar
        def initialize(x)
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
      ").to_i).to eq(3)
  end

  it "evaluates method on filtered union type 3" do
    expect(run("
      require \"prelude\"
      a = 1
      a = [1.1]
      a = [5]

      if a.is_a?(Enumerable)
        a[0]
      else
        0
      end.to_i
    ").to_i).to eq(5)
  end

  it "codegens when is_a? is always false but properties are used" do
    expect(run("
      require \"prelude\"

      class Foo
        def obj; 1 end
      end

      foo = 1
      foo.is_a?(Foo) && foo.obj && foo.obj
    ").to_b).to be_false
  end

  it "codegens is_a? on right side of and" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "codegens is_a? with virtual" do
    expect(run("
      class Foo
      end

      class Bar < Foo
      end

      foo = Bar.new || Foo.new
      foo.is_a?(Bar) ? 1 : 2
      ").to_i).to eq(1)
  end

  it "codegens is_a? with virtual and nil" do
    expect(run("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new || nil
      f.is_a?(Foo) ? 1 : 2
      ").to_i).to eq(1)
  end

  it "codegens is_a? with virtual and module" do
    expect(run("
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
      ").to_b).to be_true
  end

  it "restricts simple type with union" do
    expect(run("
      a = 1
      if a.is_a?(Int32 | Char)
        a + 1
      else
        0
      end
      ").to_i).to eq(2)
  end

  it "restricts union with union" do
    expect(run("
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
      ").to_i).to eq(3)
  end

  it "codegens is_a? with a Const does comparison and gives true" do
    expect(run("
      require \"prelude\"
      A = 1
      1.is_a?(A)
      ").to_b).to be_true
  end

  it "codegens is_a? with a Const does comparison and gives false" do
    expect(run("
      require \"prelude\"
      A = 1
      2.is_a?(A)
      ").to_b).to be_false
  end

  it "gives false if generic type doesn't match exactly" do
    expect(run("
      class Foo(T)
      end

      foo = Foo(Int32 | Float64).new
      foo.is_a?(Foo(Int32)) ? 1 : 2
      ").to_i).to eq(2)
  end

  it "does is_a? with more strict virtual type" do
    expect(run("
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
      ").to_i).to eq(2)
  end

  it "codegens is_a? casts union to nilable" do
    expect(run("
      class Foo; end

      var = \"hello\" || Foo.new || nil
      if var.is_a?(Foo | Nil)
        var2 = var
        1
      else
        2
      end
      ").to_i).to eq(2)
  end

  it "codegens is_a? casts union to nilable in method" do
    expect(run("
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
      ").to_i).to eq(2)
  end

  it "codegens is_a? from virtual type to module" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "codegens is_a? from nilable reference union type to nil" do
    expect(run("
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
      ").to_i).to eq(2)
  end

  it "codegens is_a? from nilable reference union type to type" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "says false for value.is_a?(Class)" do
    expect(run("
      1.is_a?(Class)
      ").to_b).to be_false
  end

  it "restricts type in else but lazily" do
    expect(run("
      class Foo
        def initialize(@x)
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
      ").to_i).to eq(2)
  end

  it "works with inherited generic class against an instantiation" do
    expect(run(%(
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      bar = Bar.new
      bar.is_a?(Foo(Int32))
      )).to_b).to be_true
  end

  it "works with inherited generic class against an instantiation (2)" do
    expect(run(%(
      class A
      end

      class B < A
      end

      class Foo(T)
      end

      class Bar < Foo(B)
      end

      bar = Bar.new
      bar.is_a?(Foo(A))
      )).to_b).to be_true
  end

  it "works with inherited generic class against an instantiation (3)" do
    expect(run(%(
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      bar = Bar.new
      bar.is_a?(Foo(Float32))
      )).to_b).to be_false
  end

  it "doesn't type merge (1) (#548)" do
    expect(run(%(
      class Base; end
      class A < Base; end
      class B < Base; end
      class C < Base; end

      C.new.is_a?(A | B)
      )).to_b).to be_false
  end

  it "doesn't type merge (2) (#548)" do
    expect(run(%(
      class Base; end
      class A < Base; end
      class B < Base; end
      class C < Base; end

      A.new.is_a?(A | B) && B.new.is_a?(A | B)
      )).to_b).to be_true
  end
end
