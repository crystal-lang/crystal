require "../../spec_helper"

describe "Semantic: annotation" do
  it "declares annotation" do
    result = semantic(%(
      annotation Foo
      end
      ))

    type = result.program.types["Foo"]
    type.should be_a(AnnotationType)
    type.name.should eq("Foo")
  end

  it "can't find annotation in module" do
    assert_type(%(
      annotation Foo
      end

      module Moo
      end

      {% if Moo.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
    )) { char }
  end

  it "finds annotation in module" do
    assert_type(%(
      annotation Foo
      end

      @[Foo]
      module Moo
      end

      {% if Moo.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "uses annotation value, positional" do
    assert_type(%(
      annotation Foo
      end

      @[Foo(1)]
      module Moo
      end

      {% if Moo.annotation(Foo)[0] == 1 %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "uses annotation value, keyword" do
    assert_type(%(
      annotation Foo
      end

      @[Foo(x: 1)]
      module Moo
      end

      {% if Moo.annotation(Foo)[:x] == 1 %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "finds annotation in class" do
    assert_type(%(
      annotation Foo
      end

      @[Foo]
      class Moo
      end

      {% if Moo.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "finds annotation in struct" do
    assert_type(%(
      annotation Foo
      end

      @[Foo]
      struct Moo
      end

      {% if Moo.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "finds annotation in enum" do
    assert_type(%(
      annotation Foo
      end

      @[Foo]
      enum Moo
        A = 1
      end

      {% if Moo.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "finds annotation in lib" do
    assert_type(%(
      annotation Foo
      end

      @[Foo]
      lib Moo
        A = 1
      end

      {% if Moo.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "can't find annotation in instance var" do
    assert_type(%(
      annotation Foo
      end

      class Moo
        @x : Int32 = 1

        def foo
          {% if @type.instance_vars.first.annotation(Foo) %}
            1
          {% else %}
            'a'
          {% end %}
        end
      end

      Moo.new.foo
    )) { char }
  end

  it "finds annotation in instance var (declaration)" do
    assert_type(%(
      annotation Foo
      end

      class Moo
        @[Foo]
        @x : Int32 = 1

        def foo
          {% if @type.instance_vars.first.annotation(Foo) %}
            1
          {% else %}
            'a'
          {% end %}
        end
      end

      Moo.new.foo
    )) { int32 }
  end

  it "finds annotation in instance var (assignment)" do
    assert_type(%(
      annotation Foo
      end

      class Moo
        @[Foo]
        @x = 1

        def foo
          {% if @type.instance_vars.first.annotation(Foo) %}
            1
          {% else %}
            'a'
          {% end %}
        end
      end

      Moo.new.foo
    )) { int32 }
  end

  it "finds annotation in instance var (declaration, generic)" do
    assert_type(%(
      annotation Foo
      end

      class Moo(T)
        @[Foo]
        @x : T

        def initialize(@x : T)
        end

        def foo
          {% if @type.instance_vars.first.annotation(Foo) %}
            1
          {% else %}
            'a'
          {% end %}
        end
      end

      Moo.new(1).foo
    )) { int32 }
  end
end
