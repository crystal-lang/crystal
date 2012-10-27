require 'spec_helper'

describe 'Type inference: def instance' do

  it "types a call with an int" do
    input = parse 'def foo; 1; end; foo'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call with a primitive argument" do
    input = parse 'def foo(x); x; end; foo 1'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call with an object type argument" do
    input = parse 'def foo(x); x; end; foo Object.new'
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call returning new type" do
    input = parse 'def foo; Object.new; end; foo'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.object)
  end

  test_type = "class Foo; #{rw :value}; end"

  it "types a call not returning path of argument with primitive type" do
    input = parse "#{test_type}; def foo(x); x.value; end; f = Foo.new; f.value = 1; foo(f)"
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call returning path of self" do
    input = parse "#{test_type}; f = Foo.new; f.value = Object.new; f.value"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of argument" do
    input = parse "#{test_type}; def foo(x); x.value; end; f = Foo.new; f.value = Object.new; foo(f)"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of second argument" do
    input = parse "#{test_type}; def foo(y, x); x.value; end; f = Foo.new; f.value = Object.new; foo(0, f)"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(1, '@value'))
  end

  it "types a call returning path of self" do
    input = parse %Q(
      #{test_type}
      class Foo
        def foo
          self.value
        end
      end

      x = Foo.new
      x.value = Foo.new
      x.foo)
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of self" do
    input = parse %Q(
      #{test_type}
      class Foo
        def foo
          self.value.value
        end
      end

      x = Foo.new
      x.value = Foo.new
      x.value.value = Object.new
      x.foo)
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value', '@value'))
  end

  it "types a call returning self" do
    input = parse %Q(
      class Foo
        def foo
          self
        end
      end
      Foo.new.foo
    )

    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call returning path of argument of second level call" do
    input = parse %Q(
      def foo(x)
        x
      end

      def bar(x)
        foo(x)
      end

      bar(Object.new)
    )
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call to object returning path of argument" do
    input = parse %Q(
      class Foo
        def foo(x)
          x
        end
      end
      Foo.new.foo(Object.new)
    )

    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(1))
  end

  it "types a call returning path of self of second level call" do
    input = parse %Q(
      class Foo
        def foo(x)
          x
        end
      end

      def bar(x)
        Foo.new.foo(x)
      end

      bar(Object.new)
    )
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "cache type mutation" do
    input = parse %Q(
      #{test_type}
      f = Foo.new
      f.value = 1
      )

    mod = infer_type input
    mod.types['Foo'].defs['value='].lookup_instance([ObjectType.new('Foo'), mod.int]).mutations.should eq([Mutation.new(Path.new(0, '@value'), mod.int)])
  end

  it "caches path mutation" do
    input = parse %Q(
      #{test_type}
      class Bar; end
      f = Foo.new
      f.value = Bar.new
      )

    mod = infer_type input
    mod.types['Foo'].defs['value='].lookup_instance([ObjectType.new('Foo'), ObjectType.new('Bar')]).mutations.should eq([Mutation.new(Path.new(0, '@value'), Path.new(1))])
  end

  it "caches long path mutation" do
    input = parse %Q(
      #{test_type}

      def foo(x, y)
        x.value = y.value
      end

      f = Foo.new
      f.value = Object.new

      g = Foo.new
      foo(g, f)
      )

    mod = infer_type input
    mod.defs['foo'].lookup_instance([ObjectType.new('Foo'), ObjectType.new('Foo').with_var('@value', ObjectType.new('Object'))]).
      mutations.should eq([Mutation.new(Path.new(0, '@value'), Path.new(1, '@value'))])
  end

  it "caches nested path mutation" do
    input = parse %Q(
      #{test_type}

      def foo(x)
        x.value.value = 1
      end

      f = Foo.new
      f.value = Foo.new
      foo(f)
      )

    mod = infer_type input
    mod.defs['foo'].lookup_instance([ObjectType.new('Foo').with_var('@value', ObjectType.new('Foo'))]).
      mutations.should eq([Mutation.new(Path.new(0, '@value', '@value'), mod.int)])
  end

  it "caches nested path mutation with another nested path" do
    input = parse %Q(
      #{test_type}

      def foo(x, y)
        x.value.value = y.value
      end

      f = Foo.new
      f.value = Foo.new
      g = Foo.new
      g.value = Object.new
      foo(f, g)
      )

    mod = infer_type input
    foo = ObjectType.new('Foo').with_var('@value', ObjectType.new('Foo'))
    mod.defs['foo'].lookup_instance([foo, ObjectType.new('Foo').with_var('@value', ObjectType.new('Object'))]).
      mutations.should eq([Mutation.new(Path.new(0, '@value', '@value'), Path.new(1, '@value'))])
  end

  it "caches nested path mutation with another nested recursive path" do
    input = parse %Q(
      #{test_type}

      def foo(x, y)
        x.value.value = y.value
      end

      f = Foo.new
      f.value = Foo.new
      g = Foo.new
      g.value = Foo.new
      foo(f, g)
      )

    mod = infer_type input
    foo = ObjectType.new('Foo').with_var('@value', ObjectType.new('Foo'))
    mod.defs['foo'].lookup_instance([foo, foo]).
      mutations.should eq([Mutation.new(Path.new(0, '@value', '@value'), Path.new(1, '@value'))])
  end

  it "reuses type mutation" do
    assert_type(%Q(
      #{test_type}

      def foo(x)
        x.value = 1
      end

      f = Foo.new
      foo(f)

      g = Foo.new
      foo(g)
      g
      )
    ) { ObjectType.new("Foo").with_var("@value", int) }
  end

  it "reuses path mutation" do
    assert_type(%Q(
      #{test_type}

      class Bar
        #{rw :value}
      end

      def foo(x, y)
        x.value = y
      end

      f1 = Foo.new
      b1 = Bar.new
      foo(f1, b1)

      f2 = Foo.new
      b2 = Bar.new
      foo(f2, b2)

      b2.value = 1
      f2
      )
    ) { ObjectType.new("Foo").with_var("@value", ObjectType.new("Bar").with_var("@value", int)) }
  end

  it "repoints new to correct type" do
    input = parse %Q(
      #{test_type}
      f = Foo.new
      f.value = 1
      )
    mod = infer_type input
    input[1].value.target_def.body.type.should eq(ObjectType.new('Foo').with_var('@value', mod.int))
  end

  it "repoints target defs to correct types" do
    input = parse %Q(
      #{test_type}
      class Foo
        def foo
          self.value.value
        end
      end

      x = Foo.new
      x.value = Foo.new
      x.value.value = Object.new
      x.foo)
    mod = infer_type input

    sub = ObjectType.new('Foo').with_var('@value', ObjectType.new('Object'))
    obj = ObjectType.new('Foo').with_var('@value', sub)
    input[2].value.target_def.body.type.should eq(obj)
    input[3].target_def.owner.should eq(obj)
    input[3].args[0].type.should eq(sub)
    input[3].target_def.args[0].type.should eq(sub)
    input[4].target_def.owner.should eq(sub)
  end

  it "applies all mutations to target def body type" do
    input = parse %Q(
      #{test_type}
      f = Foo.new
      f.value = Foo.new
      f.value.value = "hola")
    mod = infer_type input

    input.last.obj.target_def.body.type.should eq(input.last.obj.type)
  end

  pending "applies all mutations to target_def body type with recursive type" do
    input = parse %Q(
      class Node
        def add(x)
          @left = Node.alloc
          @left.add(x)
          @right = Node.alloc
          @right.add(x)
        end
      end

      root = Node.alloc
      root.add 'c'
      )
    mod = infer_type input
    input[2].target_def.body[2].value.target_def.body.type.should eq(input[1].type)
  end
end