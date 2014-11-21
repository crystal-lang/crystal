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

  it "codegens is_a? with nilable gives false becuase other type 1" do
    run("(1 == 1 ? nil : Reference.new).is_a?(Reference)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase other type 2" do
    run("(1 == 2 ? nil : Reference.new).is_a?(Reference)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    run("(1 == 2 ? nil : Reference.new).is_a?(String)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase no type" do
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
      ").to_i.should eq(2)
  end

  it "evaluates method on filtered union type 2" do
    run("
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
      A = 1
      1.is_a?(A)
      ").to_b.should be_true
  end

  it "codegens is_a? with a Const does comparison and gives false" do
    run("
      require \"prelude\"
      A = 1
      2.is_a?(A)
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
      ").to_i.should eq(2)
  end
end
