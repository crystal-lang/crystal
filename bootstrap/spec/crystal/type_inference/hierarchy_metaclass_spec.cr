#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: hierarchy metaclass" do
  it "types hierarchy metaclass" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.class
    ") { types["Foo"].hierarchy_type.metaclass }
  end

  it "types hierarchy metaclass method" do
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

  it "allows allocating hierarchy type when base class is abstract" do
    assert_type("
      abstract class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      bar = Bar.new || Baz.new
      baz = bar.class.allocate
      ") { types["Foo"].hierarchy_type }
  end

  pending "yields hierarchy type in block arg if class is abstract" do
    assert_type("
      require \"bootstrap\"

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
      ") { array_of(types["Foo"].hierarchy_type) }
  end
end
