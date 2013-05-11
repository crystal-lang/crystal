require 'spec_helper'

describe 'Type inference: hierarchy' do
  it "types two classes without a shared hierarchy" do
    assert_type(%(
      class Foo
      end

      class Bar
      end

      a = Foo.new || Bar.new
      )) { union_of("Foo".object, "Bar".object) }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      )) { "Foo".hierarchy }
  end

  it "types two subclasses" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      )) { "Foo".hierarchy }
  end

  it "types class and two subclasses" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      )) { "Foo".hierarchy }
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

  it "dispatches virtual method" do
    nodes = parse(%(
      class Foo
        def foo
        end
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      x = Foo.new || Bar.new || Baz.new
      x.foo
      ))
    mod = infer_type nodes
    nodes.last.target_defs.length.should eq(1)
  end

  it "dispatches virtual method with overload" do
    nodes = parse(%(
      class Foo
        def foo
        end
      end

      class Bar < Foo
        def foo
        end
      end

      class Baz < Foo
      end

      x = Foo.new || Bar.new || Baz.new
      x.foo
      ))
    mod = infer_type nodes
    nodes.last.target_defs.length.should eq(2)
  end

  it "works with restriction alpha" do
    nodes = parse(%Q(
      require "array"

      class Foo
      end

      class Bar < Foo
        def foo
        end
      end

      class Baz < Bar
      end

      class Ban < Bar
      end

      a = [nil, Foo.new, Bar.new, Baz.new]
      a.push(Baz.new || Ban.new)
      ))
    infer_type nodes
  end

  it "doesn't check cover for subclasses" do
    assert_type(%(
      class Foo
        def foo(other)
          1
        end
      end

      class Bar < Foo
        def foo(other : Bar)
          1.5
        end
      end

      f = Foo.new || Bar.new
      x = f.foo(f)
      )) { union_of(int, double) }
  end
end
