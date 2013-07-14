require 'spec_helper'

describe 'Codegen: is_a?' do
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
    run("(1 == 1 ? nil : Reference.new).is_a?(Object)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase other type 2" do
    run("(1 == 2 ? nil : Reference.new).is_a?(Object)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    run("(1 == 2 ? nil : Reference.new).is_a?(String)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    run("1.is_a?(Object)").to_b.should be_true
  end

  it "evaluate method on filtered type" do
    run("a = 1; a = 'a'; if a.is_a?(Char); a.ord; else; 0; end").to_i.should eq(?a.ord)
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
      class Nil
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
    run(%q(
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
      )).to_i.should eq(2)
  end

  it "evaluates method on filtered union type 2" do
    run(%q(
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
      )).to_i.should eq(3)
  end

  it "evaluates method on filtered union type 3" do
    run(%q(
      require "prelude"
      a = 1
      a = [1.1]
      a = [5]

      if a.is_a?(Enumerable)
        a[0]
      else
        0
      end.to_i
    )).to_i.should eq(5)
  end

  it "codegens when is_a? is always false but properties are used" do
    run(%q(
      class Foo
        def obj; 1 end
      end

      foo = 1
      foo.is_a?(Foo) && foo.obj && foo.obj
    )).to_b.should be_false
  end

  it "codegens is_a? on right side of and" do
    run(%q(
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
      )).to_i.should eq(1)
  end

  it "codegens is_a? with hierarchy" do
    run(%q(
      class Foo
      end

      class Bar < Foo
      end

      foo = Bar.new || Foo.new
      foo.is_a?(Bar) ? 1 : 2
      )).to_i.should eq(1)
  end
end
