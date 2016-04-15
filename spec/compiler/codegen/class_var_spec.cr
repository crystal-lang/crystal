require "../../spec_helper"

describe "Codegen: class var" do
  it "codegens class var" do
    run("
      class Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "codegens class var as nil" do
    run("
      struct Nil; def to_i; 0; end; end

      class Foo
        @@foo = nil

        def self.foo
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i.should eq(0)
  end

  it "codegens class var inside instance method" do
    run("
      class Foo
        @@foo = 1

        def foo
          @@foo
        end
      end

      Foo.new.foo
      ").to_i.should eq(1)
  end

  it "codegens class var as nil if assigned for the first time inside method" do
    run("
      struct Nil; def to_i; 0; end; end

      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i.should eq(1)
  end

  it "codegens class var inside module" do
    run("
      module Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "accesses class var from fun literal" do
    run("
      class Foo
        @@a = 1

        def self.foo
          ->{ @@a }.call
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "reads class var before initializing it (hoisting)" do
    run(%(
      x = Foo.var

      class Foo
        @@var = 42

        def self.var
          @@var
        end
      end

      x
      )).to_i.should eq(42)
  end

  it "uses var in class var initializer" do
    run(%(
      class Foo
        @@var : Int32
        @@var = begin
          a = class_method
          a + 3
        end

        def self.var
          @@var
        end

        def self.class_method
          1 + 2
        end
      end

      Foo.var
      )).to_i.should eq(6)
  end

  it "reads simple class var before another complex one" do
    run(%(
      class Foo
        @@var2 : Int32
        @@var2 = @@var + 1

        @@var = 41

        def self.var2
          @@var2
        end
      end

      Foo.var2
      )).to_i.should eq(42)
  end

  it "initializes class var of union with single type" do
    run(%(
      class Foo
        @@var : Int32 | String
        @@var = 42

        def self.var
          @@var
        end
      end

      var = Foo.var
      if var.is_a?(Int32)
        var
      else
        0
      end
      )).to_i.should eq(42)
  end

  it "initializes class var with array literal" do
    run(%(
      require "prelude"

      class Foo
        @@var = [1, 2, 4]

        def self.var
          @@var
        end
      end

      Foo.var.size
      )).to_i.should eq(3)
  end

  it "initializes class var conditionally" do
    run(%(
      class Foo
        if 1 == 2
          @@x = 3
        else
          @@x = 4
        end

        def self.x
          @@x
        end
      end

      Foo.x
      )).to_i.should eq(4)
  end

  it "codegens second class var initializer" do
    run(%(
      class Foo
        @@var = 1
        @@var = 2

        def self.var
          @@var
        end
      end

      Foo.var
      )).to_i.should eq(2)
  end
end
