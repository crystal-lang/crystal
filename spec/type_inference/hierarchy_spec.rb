require 'spec_helper'

describe 'Type inference: hierarchy' do
  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      )) { HierarchyType.new(self.types["Foo"]) }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      )) { HierarchyType.new(self.types["Foo"]) }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      )) { HierarchyType.new(self.types["Foo"]) }
  end

  it "types method call of hierarchy type" do
    assert_type(%(
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      a.foo
      )) { int }
  end

  it "types method call of hierarchy type with override" do
    assert_type(%(
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          1.5
        end
      end

      a = Foo.new || Bar.new
      a.foo
      )) { union_of(int, double) }
  end
end
