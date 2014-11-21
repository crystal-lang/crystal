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
end
