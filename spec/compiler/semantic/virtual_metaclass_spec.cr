require "../../spec_helper"

describe "Semantic: virtual metaclass" do
  it "types virtual metaclass" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { types["Foo"].virtual_type.metaclass }
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.class
      CRYSTAL
  end

  it "types virtual metaclass method" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, float64) }
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
      CRYSTAL
  end

  it "allows allocating virtual type when base class is abstract" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      require "prelude"

      abstract class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      bar = Bar.new || Baz.new
      baz = bar.class.allocate
      CRYSTAL
  end

  it "yields virtual type in block arg if class is abstract" do
    assert_type(<<-CRYSTAL) { array_of(types["Foo"].virtual_type) }
      require "prelude"

      abstract class Foo
        def clone
          self.class.allocate
        end

        def to_s
          "Foo"
        end
      end

      class Bar < Foo
        def to_s
          "Bar"
        end
      end

      class Baz < Foo
        def to_s
          "Baz"
        end
      end

      a = [Bar.new, Baz.new] of Foo
      b = a.map { |e| e.clone }
      CRYSTAL
  end

  it "merges metaclass types" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type.metaclass }
      class Foo
      end

      class Bar < Foo
      end

      Foo || Bar
      CRYSTAL
  end

  it "merges metaclass types with 3 types" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type.metaclass }
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      Foo || Bar || Baz
      CRYSTAL
  end

  it "types metaclass node" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type.metaclass }
      class Foo
      end

      class Bar < Foo
      end

      a = uninitialized Foo.class
      a
      CRYSTAL
  end

  it "allows passing metaclass to virtual metaclass restriction" do
    assert_type(<<-CRYSTAL) { types["Foo"].metaclass }
      class Foo
      end

      def foo(x : Foo.class)
        x
      end

      foo(Foo)
      CRYSTAL
  end

  it "allows passing metaclass to virtual metaclass restriction" do
    assert_type(<<-CRYSTAL) { types["Bar"].metaclass }
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : Foo.class)
        x
      end

      foo(Bar)
      CRYSTAL
  end

  it "restricts virtual metaclass to Class (#11376)" do
    assert_type(<<-CRYSTAL) { nilable types["Foo"].virtual_type.metaclass }
      class Foo
      end

      class Bar < Foo
      end

      x = Foo || Bar
      x if x.is_a?(Class)
      CRYSTAL
  end
end
