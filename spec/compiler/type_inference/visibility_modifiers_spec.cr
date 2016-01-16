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

  it "allows invoking protected method from container to contained" do
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

  it "allows invoking protected method from contained to container" do
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

  context "with trailing newline" do
    it "disallows invoking private method" do
      assert_error %(
        class Foo
          private

          def foo; end

          def bar; end
        end

        foo = Foo.new
        foo.bar
      ),
      "private method 'bar' called for Foo"
    end

    it "resets to public after ClassDef" do
      assert_type(%(
        class Foo
          private

          def foo
            "private"
          end

          class Bar
            def num
              1_i32
            end
          end
        end

        Foo::Bar.new.num
      )) { int32 }
    end

    it "resets to public after ModuleDef" do
      assert_type(%(
        class Foo
          private

          def foo
            "private"
          end

          module Bar
            def self.test
              1_i32
            end
          end
        end

        Foo::Bar.test
      )) { int32 }
    end

    it "is compatible with 'private def foo; end' syntax" do
      assert_error %(
        class Foo
          protected

          def bar; end

          private def foo; end

          def baz; end
        end

        Foo.new.baz
      ),
      "protected method 'baz' called for Foo"
    end

    it "is overridden by 'private def foo; end' syntax" do
      assert_error %(
        class Foo
          protected

          def bar; end

          private def foo; end

          def baz; end
        end

        Foo.new.foo
      ),
      "private method 'foo' called for Foo"
    end

    it "sets the visibility of macros" do
      assert_error %(
        class Foo
          macro def_name(name)
            def {{name.id}}
              {{name}}
            end
          end

          private

          def one
            1
          end

          def_name(:bar)
        end

        Foo.new.bar
      ),
      "private method 'bar' called for Foo"
    end

    it "works when code is pasted by macros" do
      assert_error %(
        macro build(name)
          class {{name.id}}
            {{yield}}
          end
        end

        build Test do
          private

          def foo; end

          def bar; end
        end

        Test.new.bar
      ),
      "private method 'bar' called for Test"
    end
  end
end
