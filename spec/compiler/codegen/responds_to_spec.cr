require "../../spec_helper"

describe "Codegen: responds_to?" do
  it "codegens responds_to? true for simple type" do
    run("1.responds_to?(:\"+\")").to_b.should be_true
  end

  it "codegens responds_to? false for simple type" do
    run("1.responds_to?(:foo)").to_b.should be_false
  end

  it "codegens responds_to? with union gives true" do
    run("(1 == 1 ? 1 : 'a').responds_to?(:\"+\")").to_b.should be_true
  end

  it "codegens responds_to? with union gives false" do
    run("(1 == 1 ? 1 : 'a').responds_to?(:\"foo\")").to_b.should be_false
  end

  it "codegens responds_to? with nilable gives true" do
    run("struct Nil; def foo; end; end; (1 == 1 ? nil : Reference.new).responds_to?(:foo)").to_b.should be_true
  end

  it "codegens responds_to? with nilable gives false because other type 1" do
    run("(1 == 1 ? nil : Reference.new).responds_to?(:foo)").to_b.should be_false
  end

  it "codegens responds_to? with nilable gives false because other type 2" do
    run("class Reference; def foo; end; end; (1 == 2 ? nil : Reference.new).responds_to?(:foo)").to_b.should be_true
  end

  it "codegends responds_to? with generic class (1)" do
    run(%(
      class Foo(T)
        def foo
        end
      end

      Foo(Int32).new.responds_to?(:foo)
      )).to_b.should be_true
  end

  it "codegends responds_to? with generic class (2)" do
    run(%(
      class Foo(T)
        def foo
        end
      end

      Foo(Int32).new.responds_to?(:bar)
      )).to_b.should be_false
  end

  it "works with virtual type" do
    run(%(
      class Foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      foo = Bar.new || Foo.new
      foo.responds_to?(:foo)
      )).to_b.should be_true
  end

  it "works with two virtual types" do
    run(%(
      class Foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Bar2 < Bar
      end

      class Other
      end

      class Sub < Other
        def foo
          3
        end
      end

      class Sub2 < Sub
        def foo
          4
        end
      end

      foo = Sub2.new || Bar.new || Bar2.new || Sub.new || Sub2.new
      foo.responds_to?(:foo)
      )).to_b.should be_true
  end

  it "works with virtual class type (1) (#1926)" do
    run(%(
      class Foo
      end

      class Bar < Foo
        def self.foo
          1
        end
      end

      foo = Bar || Foo
      foo.responds_to?(:foo)
      )).to_b.should be_true
  end

  it "works with virtual class type (2) (#1926)" do
    run(%(
      class Foo
      end

      class Bar < Foo
        def self.foo
          1
        end
      end

      foo = Foo || Bar
      foo.responds_to?(:foo)
      )).to_b.should be_false
  end

  it "works with module" do
    run(%(
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      class Bar
        include Moo

        def foo
          1
        end
      end

      ptr = Pointer(Moo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value = Foo.new

      moo = ptr.value
      moo.responds_to?(:foo)
      )).to_b.should be_true
  end

  it "does for generic instance type metaclass (#4353)" do
    run(%(
      class MyGeneric(T)
        def self.hallo
          1
        end
      end

      MyGeneric(String).responds_to? :hallo
      )).to_b.should be_true
  end
end
