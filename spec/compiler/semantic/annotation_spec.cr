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

  it "can't find annotation in module, when other annotations are present" do
    assert_type(%(
      annotation Foo
      end

      annotation Bar
      end

      @[Bar]
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

  it "can't find annotation in instance var, when other annotations are present" do
    assert_type(%(
      annotation Foo
      end

      annotation Bar
      end

      class Moo
        @[Bar]
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

  it "overrides annotation value in type" do
    assert_type(%(
      annotation Foo
      end

      @[Foo(1)]
      module Moo
      end

      @[Foo(2)]
      module Moo
      end

      {% if Moo.annotation(Foo)[0] == 2 %}
        1
      {% else %}
        'a'
      {% end %}
    )) { int32 }
  end

  it "overrides annotation in instance var" do
    assert_type(%(
      annotation Foo
      end

      class Moo
        @[Foo(1)]
        @x : Int32 = 1
      end

      class Moo
        @[Foo(2)]
        @x : Int32 = 1

        def foo
          {% if @type.instance_vars.first.annotation(Foo)[0] == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        end
      end

      Moo.new.foo
    )) { int32 }
  end

  it "errors if annotation doesn't exist" do
    assert_error %(
      @[DoesntExist]
      class Moo
      end
      ),
      "undefined constant DoesntExist"
  end

  it "errors if annotation doesn't point to an annotation type" do
    assert_error %(
      @[Int32]
      class Moo
      end
      ),
      "Int32 is not an annotation, it's a struct"
  end

  it "errors if using annotation other than ThreadLocal for class vars" do
    assert_error %(
      annotation Foo
      end

      class Moo
        @[Foo]
        @@x = 0
      end
      ),
      "class variables can only be annotated with ThreadLocal"
  end

  it "adds annotation on def" do
    assert_type(%(
      annotation Foo
      end

      class Moo
        @[Foo]
        def foo
        end
      end

      {% if Moo.methods.first.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
      )) { int32 }
  end

  it "can't find annotation on def" do
    assert_type(%(
      annotation Foo
      end

      class Moo
        def foo
        end
      end

      {% if Moo.methods.first.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
      )) { char }
  end

  it "can't find annotation on def, when other annotations are present" do
    assert_type(%(
      annotation Foo
      end

      annotation Bar
      end

      class Moo
        @[Bar]
        def foo
        end
      end

      {% if Moo.methods.first.annotation(Foo) %}
        1
      {% else %}
        'a'
      {% end %}
      )) { char }
  end

  it "errors if using invalid annotation on fun" do
    assert_error %(
      annotation Foo
      end

      @[Foo]
      fun foo : Void
      end
      ),
      "funs can only be annotated with: NoInline, AlwaysInline, Naked, ReturnsTwice, Raises, CallConvention"
  end

  it "doesn't carry link attribute from lib to fun" do
    semantic(%(
      @[Link("foo")]
      lib LibFoo
        fun foo
      end
      ))
  end
end
