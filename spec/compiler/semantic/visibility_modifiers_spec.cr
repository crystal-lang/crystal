require "../../spec_helper"

describe "Visibility modifiers" do
  it "disallows invoking private method" do
    assert_error %(
      class Foo
        private def foo
          1
        end
      end

      Foo.new.foo
      ),
      "private method 'foo' called for Foo"
  end

  it "allows setting visibility modifier to macro" do
    assert_error %(
      class Object
        macro x
          def foo
          end
        end
      end

      class Foo
        private x
      end

      Foo.new.foo
      ),
      "private method 'foo' called for Foo"
  end

  it "allows setting visibility modifier to macro that generates many methods (1)" do
    assert_error %(
      class Object
        macro x
          def foo
          end

          def bar
          end
        end
      end

      class Foo
        private x
      end

      Foo.new.foo
      ),
      "private method 'foo' called for Foo"
  end

  it "allows setting visibility modifier to macro that generates many methods (2)" do
    assert_error %(
      class Object
        macro x
          def foo
          end

          def bar
          end
        end
      end

      class Foo
        private x
      end

      Foo.new.bar
      ),
      "private method 'bar' called for Foo"
  end

  it "allows invoking private method from the same class" do
    assert_type(%(
      class Foo
        private def foo
          1
        end

        def bar
          self.foo
        end
      end

      Foo.new.bar
      )) { int32 }
  end

  it "allows invoking protected method from the same class" do
    assert_type(%(
      class Foo
        protected def foo
          1
        end

        def bar
          self.foo
        end
      end

      Foo.new.bar
      )) { int32 }
  end

  it "allows invoking protected method from subclass" do
    assert_type(%(
      class Foo
        protected def foo
          1
        end
      end

      class Bar < Foo
        def bar
          Foo.new.foo
        end
      end

      Bar.new.bar
      )) { int32 }
  end

  it "allows invoking protected method from subclass (2)" do
    assert_type(%(
      class Foo
        protected def foo
          1
        end
      end

      class Bar < Foo
      end

      class Baz < Foo
        def baz
          Bar.new.foo
        end
      end

      Baz.new.baz
      )) { int32 }
  end

  it "errors if invoking protected method from top-level" do
    assert_error %(
      class Foo
        protected def foo
        end
      end

      Foo.new.foo
      ),
      "protected method 'foo' called for Foo"
  end

  it "errors if invoking protected method from non-subclass" do
    assert_error %(
      class Foo
        protected def foo
        end
      end

      class Bar
        def bar
          Foo.new.foo
        end
      end

      Bar.new.bar
      ),
      "protected method 'foo' called for Foo"
  end

  it "errors if invoking protected method from non-subclass, generated with macro that generates a macro" do
    assert_error %(
      class Object
        macro y
          def foo
          end
        end

        macro x
          y
        end
      end

      class Foo
        protected x
      end

      Foo.new.foo
      ),
      "protected method 'foo' called for Foo"
  end

  it "errors if applying visibility modifier to non-def or non-call" do
    assert_error %(
      class Foo
        private 1
      end
      ),
      "can't apply visibility modifier"
  end

  it "allows invoking protected from instance to class" do
    assert_type(%(
      class Foo
        def instance_foo
          Foo.class_foo
        end

        protected def self.class_foo
          1
        end
      end

      Foo.new.instance_foo
      )) { int32 }
  end

  it "automatically makes initialize be protected" do
    assert_error %(
      class Foo
        def initialize(x)
        end
      end

      foo = Foo.new(1)
      foo.initialize(2)
      ),
      "protected method 'initialize' called for Foo"
  end

  it "allows invoking private setter with self" do
    assert_type(%(
      class Foo
        private def x=(x)
          x
        end

        def foo
          self.x = 1
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "allows invoking protected method from namespace to namespaced type" do
    assert_type(%(
      class Foo
        def foo
          Bar.new.bar
        end

        class Bar
          protected def bar
            1
          end
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "allows invoking protected method from namespaced type to namespace" do
    assert_type(%(
      class Foo
        protected def foo
          1
        end

        class Bar
          def bar
            Foo.new.foo
          end
        end
      end

      Foo::Bar.new.bar
      )) { int32 }
  end

  it "allows invoking protected method between types in the same namespace" do
    assert_type(%(
      module NS1
        class NS2
          class Foo
            def foo
              Bar.new.bar
            end
          end

          class Bar
            protected def bar
              1
            end
          end
        end
      end

      NS1::NS2::Foo.new.foo
      )) { int32 }
  end

  it "allows invoking protected method between types in the same namespace when inheriting" do
    assert_type(%(
      module NS1
        class NS2
          class Foo
            def foo
              Bar.new.bar
            end
          end

          class Bar
            protected def bar
              1
            end
          end
        end
      end

      class MyFoo < NS1::NS2::Foo
      end

      MyFoo.new.foo
      )) { int32 }
  end

  it "allows invoking protected method from virtual type" do
    assert_type(%(
      abstract class Foo
        def foo
          bar
        end
      end

      class Bar < Foo
        protected def bar
          1
        end
      end

      class Baz < Foo
        protected def bar
          1.5
        end
      end

      (Bar.new || Baz.new).foo
      )) { union_of int32, float64 }
  end

  it "allows calling protected method from nested generic class (1)" do
    assert_type(%(
      class Foo
        class Bar(U)
          def bar
            Foo.new.foo
          end
        end

        protected def foo
          1
        end
      end

      Foo::Bar(Int32).new.bar
      )) { int32 }
  end

  it "allows calling protected method from nested generic class (2)" do
    assert_type(%(
      class Foo(T)
        class Bar(U)
          def bar
            Foo(Int32).new.foo
          end
        end

        protected def foo
          1
        end
      end

      Foo::Bar(Int32).new.bar
      )) { int32 }
  end

  it "gives correct error on unknown call (#2838)" do
    assert_error %(
      private foo
      ),
      "undefined local variable or method 'foo'"
  end

  it "defines protected initialize (#7501)" do
    assert_error %(
      class Foo
        protected def initialize
        end
      end

      Foo.new
      ),
      "protected method 'new' called for Foo.class"
  end

  it "handles virtual types (#8561)" do
    assert_no_errors <<-CRYSTAL
      module Namespace
        class Foo
          protected def foo
          end
        end

        class Bar
          def bar
            Foo.new.foo
          end
        end

        class Baz < Bar
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar.bar
          end
        end
      end

      Namespace::Baz.new.bar
      CRYSTAL
  end
end
