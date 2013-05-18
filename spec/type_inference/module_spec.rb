require 'spec_helper'

describe 'Type inference: module' do
  it "includes but not a module" do
    assert_error "class Foo; end; class Bar; include Foo; end",
      "Foo is not a module"
  end

  it "includes module in a class" do
    assert_type("module Foo; def foo; 1; end; end; class Bar; include Foo; end; Bar.new.foo") { int }
  end

  it "includes module in a module" do
    assert_type(%q(
      module A
        def foo
          1
        end
      end

      module B
        include A
      end

      class X
        include B
      end

      X.new.foo
      )) { int }
  end

  it "finds in module when included" do
    assert_type(%q(
      module A
        class B
          def foo; 1; end
        end
      end

      include A

      B.new.foo
    )) { int }
  end

  it "includes generic module with type" do
    assert_type(%q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar
        include Foo(Int)
      end

      Bar.new.foo(1)
      )) { int }
  end

  it "includes generic module and errors in call" do
    assert_error %q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar
        include Foo(Int)
      end

      Bar.new.foo(1.5)
      ),
      "no overload matches"
  end

  it "includes module but not generic" do
    assert_error %q(
      module Foo
      end

      class Bar
        include Foo(Int)
      end
      ),
      "Foo is not a generic module"
  end

  it "includes module but wrong number of arguments" do
    assert_error %q(
      module Foo(T1, T2)
      end

      class Bar
        include Foo(Int)
      end
      ),
      "wrong number of type vars for Foo(T1, T2) (1 for 2)"
  end

  it "includes generic module but wrong number of arguments 2" do
    assert_error %q(
      module Foo(T)
      end

      class Bar
        include Foo
      end
      ),
      "Foo(T) is a generic module"
  end

  it "includes generic module implicitly" do
    assert_type(%q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(U)
        include Foo
      end

      Bar(Int).new.foo(1)
      )) { int }
  end

  it "includes generic module implicitly 2" do
    assert_type(%q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(T)
        include Foo
      end

      Bar(Int).new.foo(1)
      )) { int }
  end

  it "includes generic module implicitly and errors on call" do
    assert_error %q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(U)
        include Foo
      end

      Bar(Int).new.foo(1.5)
      ),
      "no overload matches"
  end

  it "includes generic module explicitly" do
    assert_type(%q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(U)
        include Foo(U)
      end

      Bar(Int).new.foo(1)
      )) { int }
  end

  it "includes generic module explicitly and errors" do
    assert_error %q(
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(U)
        include Foo(U)
      end

      Bar(Int).new.foo(1.5)
      ),
      "no overload matches"
  end

  it "reports can't use instance variables inside module" do
    assert_error "def foo; @a = 1; end; foo",
      "can't use instance variables at the top level"
  end

  it "works with int including enumerable" do
    assert_type(%q(
      require "prelude"

      class Int
        include Enumerable(Int)

        def each
          yield self
          yield self + 2
        end
      end

      1.map { |x| x * 0.5 }
      )) { array_of(double) }
  end

  it "works with range and map" do
    assert_type(%q(
      require "prelude"
      (1..3).map { |x| x * 0.5 }
      )) { array_of(double) }
  end

end
