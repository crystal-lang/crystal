#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: class" do
  it "types Const#allocate" do
    assert_type("class Foo; end; Foo.allocate") { types["Foo"] }
  end

  it "types Const#new" do
    assert_type("class Foo; end; Foo.new") { types["Foo"] }
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int32 }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { types["Foo"].types["Bar"] }
  end

  it "types instance variable" do
    result = assert_type("
      class Foo
        def initialize(coco)
          @coco = coco
        end
      end

      f = Foo.new(2)
      f
    ") { types["Foo"] }
    type = result.node.type
    assert_type type, InstanceVarContainer
    type.instance_vars["@coco"].type.should eq(result.program.int32)
  end

  it "types nilable instance variable" do
    assert_type("
      class Foo
        def coco
          @coco
        end
      end

      f = Foo.new
      f.coco
    ") { |mod| mod.nil }
  end

  it "types nilable instance variable 2" do
    assert_type("
      class Foo
        def coco=(coco)
          @coco = coco
        end
        def coco
          @coco
        end
      end

      f = Foo.new
      f.coco = 1
      f.coco
    ") { |mod| union_of(mod.nil, int32) }
  end

  it "does automatic inference of new for generic types" do
    assert_type("
      class Box(T)
        def initialize(value : T)
          @value = value
        end
      end

      b = Box.new(10)
      ") do
        box = types["Box"]
        assert_type box, GenericClassType
        box.instantiate([int32])
      end
  end

  it "does automatic type inference of new for generic types 2" do
    assert_type("
      class Box(T)
        def initialize(x, value : T)
          @value = value
        end
      end

      b1 = Box.new(1, 10)
      b2 = Box.new(1, false)
      ") do
        box = types["Box"]
        assert_type box, GenericClassType
        box.instantiate([bool])
      end
  end

  it "does automatic type inference of new for nested generic type" do
    assert_type("
      class Foo
        class Bar(T)
          def initialize(x : T)
            @x = x
          end
        end
      end

      Foo::Bar.new(1)
      ") do
        foo = types["Foo"]
        assert_type foo, ContainedType
        bar = foo.types["Bar"]
        assert_type bar, GenericClassType
        bar.instantiate([int32])
    end
  end

  it "reports uninitialized constant" do
    assert_error "Foo.new",
      "uninitialized constant Foo"
  end

  it "reports undefined method when method inside a class" do
    assert_error "class Int; def foo; 1; end; end; foo",
      "undefined local variable or method 'foo'"
  end

  it "reports undefined instance method" do
    assert_error "1.foo",
      "undefined method 'foo' for Int"
  end

  it "reports unknown class when extending" do
    assert_error "class Foo < Bar; end",
      "uninitialized constant Bar"
  end

  it "reports superclass mismatch" do
    assert_error "class Foo; end; class Bar; end; class Foo < Bar; end",
      "superclass mismatch for class Foo (Bar for Reference)"
  end

  it "reports wrong number of arguments for initialize" do
    assert_error "
      class Foo
        def initialize(x, y)
        end
      end

      f = Foo.new
      ",
      "wrong number of arguments"
  end

  it "reports can't instantiate abstract class on new" do
    assert_error "
      abstract class Foo; end
      Foo.new
      ",
      "can't instantiate abstract class Foo"
  end

  it "reports can't instantiate abstract class on allocate" do
    assert_error "
      abstract class Foo; end
      Foo.allocate
      ",
      "can't instantiate abstract class Foo"
  end
end
