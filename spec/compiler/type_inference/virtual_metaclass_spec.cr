require "../../spec_helper"

describe "Type inference: virtual metaclass" do
  it "types virtual metaclass" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.class
    ") { types["Foo"].virtual_type.metaclass }
  end

  it "types virtual metaclass method" do
    assert_type("
      class Foo
        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          1.5
        end
      end

      f = Foo.new || Bar.new
      f.class.foo
    ") { union_of(int32, float64) }
  end

  it "allows allocating virtual type when base class is abstract" do
    assert_type("
      abstract class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      bar = Bar.new || Baz.new
      baz = bar.class.allocate
      ") { types["Foo"].virtual_type }
  end

  it "yields virtual type in block arg if class is abstract" do
    assert_type("
      require \"prelude\"

      abstract class Foo
        def clone
          self.class.allocate
        end

        def to_s
          \"Foo\"
        end
      end

      class Bar < Foo
        def to_s
          \"Bar\"
        end
      end

      class Baz < Foo
        def to_s
          \"Baz\"
        end
      end

      a = [Bar.new, Baz.new] of Foo
      b = a.map { |e| e.clone }
      ") { array_of(types["Foo"].virtual_type) }
  end

  it "merges metaclass types" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      Foo || Bar
      ") { types["Foo"].virtual_type.metaclass }
  end

  it "merges metaclass types with 3 types" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      Foo || Bar || Baz
      ") { types["Foo"].virtual_type.metaclass }
  end

  it "types metaclass node" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      a :: Foo.class
      a
      ") { types["Foo"].virtual_type.metaclass }
  end

  it "allows passing metaclass to virtual metaclass restriction" do
    assert_type("
      class Foo
      end

      def foo(x : Foo.class)
        x
      end

      foo(Foo)
      ") { types["Foo"].metaclass }
  end

  it "allows passing metaclass to virtual metaclass restriction" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : Foo.class)
        x
      end

      foo(Bar)
      ") { types["Bar"].metaclass }
  end
end
