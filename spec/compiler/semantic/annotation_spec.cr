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

  describe "arguments" do
    describe "#args" do
      it "returns an empty TupleLiteral if there are none defined" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          module Moo
          end

          {% if (pos_args = Moo.annotation(Foo).args) && pos_args.is_a? TupleLiteral && pos_args.empty? %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "returns a TupleLiteral if there are positional arguments defined" do
        assert_type(%(
          annotation Foo
          end

          @[Foo(1, "foo", true)]
            module Moo
          end

          {% if Moo.annotation(Foo).args == {1, "foo", true} %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end
    end

    describe "#named_args" do
      it "returns an empty NamedTupleLiteral if there are none defined" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          module Moo
          end

          {% if (args = Moo.annotation(Foo).named_args) && args.is_a? NamedTupleLiteral && args.empty? %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "returns a NamedTupleLiteral if there are named arguments defined" do
        assert_type(%(
          annotation Foo
          end

          @[Foo(extra: "three", "foo": 99)]
            module Moo
          end

          {% if Moo.annotation(Foo).named_args == {extra: "three", foo: 99} %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end
    end

    it "returns a correctly with named and positional args" do
      assert_type(%(
        annotation Foo
        end

        @[Foo(1, "foo", true, foo: "bar", "cat": 0..0)]
          module Moo
        end

        {% if Moo.annotation(Foo).args == {1, "foo", true} && Moo.annotation(Foo).named_args == {foo: "bar", cat: 0..0} %}
          1
        {% else %}
          'a'
        {% end %}
      )) { int32 }
    end
  end

  describe "#annotations" do
    describe "all types" do
      it "returns an empty array if there are none defined" do
        assert_type(%(
          annotation Foo; end

          module Moo
          end

          {% if Moo.annotations.empty? %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations on a module" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          @[Foo]
          @[Bar]
          module Moo
          end

          {% if Moo.annotations.map(&.name.id) == [Foo.id, Bar.id] %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations on a class" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          @[Foo]
          @[Bar]
          class Moo
          end

          {% if Moo.annotations.map(&.name.id) == [Foo.id, Bar.id] %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations on a struct" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          @[Foo]
          @[Bar]
          struct Moo
          end

          {% if Moo.annotations.map(&.name.id) == [Foo.id, Bar.id] %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations on a enum" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          @[Foo]
          @[Bar]
          enum Moo
            A = 1
          end

          {% if Moo.annotations.map(&.name.id) == [Foo.id, Bar.id] %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations on a lib" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          @[Foo]
          @[Bar]
          lib Moo
            A = 1
          end

          {% if Moo.annotations.map(&.name.id) == [Foo.id, Bar.id] %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations in instance var (declaration)" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          class Moo
            @[Foo]
            @[Bar]
            @x : Int32 = 1

            def foo
              {% if @type.instance_vars.first.annotations.size == 2 %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new.foo
        )) { int32 }
      end

      it "finds annotations in instance var (declaration, generic)" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          class Moo(T)
            @[Foo]
            @[Bar]
            @x : T

            def initialize(@x : T)
            end

            def foo
              {% if @type.instance_vars.first.annotations.size == 2 %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new(1).foo
        )) { int32 }
      end

      it "adds annotations on def" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          class Moo
            @[Foo]
            @[Bar]
            def foo
            end
          end

          {% if Moo.methods.first.annotations.size == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations in generic parent (#7885)" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          @[Foo(1)]
          @[Bar(2)]
          class Parent(T)
          end

          class Child < Parent(Int32)
          end

          {% if Child.superclass.annotations.map(&.[0]) == [1, 2] %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "find annotations on method parameters" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          class Moo
            def foo(@[Foo] @[Bar] value)
            end
          end

          {% if Moo.methods.first.args.first.annotations.size == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end
    end

    describe "of a specific type" do
      it "returns an empty array if there are none defined" do
        assert_type(%(
          annotation Foo
          end

          module Moo
          end

          {% if Moo.annotations(Foo).size == 0 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations on a module" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          @[Foo]
          module Moo
          end

          {% if Moo.annotations(Foo).size == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "uses annotations value, positional" do
        assert_type(%(
          annotation Foo
          end

          @[Foo(1)]
          @[Foo(2)]
          module Moo
          end

          {% if Moo.annotations(Foo)[0][0] == 1 && Moo.annotations(Foo)[1][0] == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "uses annotations value, keyword" do
        assert_type(%(
          annotation Foo
          end

          @[Foo(x: 1)]
          @[Foo(x: 2)]
          module Moo
          end

          {% if Moo.annotations(Foo)[0][:x] == 1 && Moo.annotations(Foo)[1][:x] == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations in class" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          @[Foo]
          @[Foo]
          class Moo
          end

          {% if Moo.annotations(Foo).size == 3 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations in struct" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          @[Foo]
          @[Foo]
          @[Foo]
          struct Moo
          end

          {% if Moo.annotations(Foo).size == 4 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations in enum" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          enum Moo
            A = 1
          end

          {% if Moo.annotations(Foo).size == 1 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "finds annotations in lib" do
        assert_type(%(
          annotation Foo
          end

          @[Foo]
          @[Foo]
          lib Moo
            A = 1
          end

          {% if Moo.annotations(Foo).size == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "can't find annotations in instance var" do
        assert_type(%(
          annotation Foo
          end

          class Moo
            @x : Int32 = 1

            def foo
              {% unless @type.instance_vars.first.annotations(Foo).empty? %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new.foo
        )) { char }
      end

      it "can't find annotations in instance var, when other annotations are present" do
        assert_type(%(
          annotation Foo
          end

          annotation Bar
          end

          class Moo
            @[Bar]
            @x : Int32 = 1

            def foo
              {% unless @type.instance_vars.first.annotations(Foo).empty? %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new.foo
        )) { char }
      end

      it "finds annotations in instance var (declaration)" do
        assert_type(%(
          annotation Foo
          end

          class Moo
            @[Foo]
            @[Foo]
            @x : Int32 = 1

            def foo
              {% if @type.instance_vars.first.annotations(Foo).size == 2 %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new.foo
        )) { int32 }
      end

      it "finds annotations in instance var (declaration, generic)" do
        assert_type(%(
          annotation Foo
          end

          class Moo(T)
            @[Foo]
            @x : T

            def initialize(@x : T)
            end

            def foo
              {% if @type.instance_vars.first.annotations(Foo).size == 1 %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new(1).foo
        )) { int32 }
      end

      it "collects annotations values in type" do
        assert_type(%(
          annotation Foo
          end

          @[Foo(1)]
          module Moo
          end

          @[Foo(2)]
          module Moo
          end

          {% if Moo.annotations(Foo)[0][0] == 1 && Moo.annotations(Foo)[1][0] == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "overrides annotations value in type" do
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
              {% if @type.instance_vars.first.annotations(Foo).size == 1 && @type.instance_vars.first.annotations(Foo)[0][0] == 2 %}
                1
              {% else %}
                'a'
              {% end %}
            end
          end

          Moo.new.foo
        )) { int32 }
      end

      it "adds annotations on def" do
        assert_type(%(
          annotation Foo
          end

          class Moo
            @[Foo]
            @[Foo]
            def foo
            end
          end

          {% if Moo.methods.first.annotations(Foo).size == 2 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end

      it "can't find annotations on def" do
        assert_type(%(
          annotation Foo
          end

          class Moo
            def foo
            end
          end

          {% unless Moo.methods.first.annotations(Foo).empty? %}
            1
          {% else %}
            'a'
          {% end %}
        )) { char }
      end

      it "can't find annotations on def, when other annotations are present" do
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

          {% unless Moo.methods.first.annotations(Foo).empty? %}
            1
          {% else %}
            'a'
          {% end %}
        )) { char }
      end

      it "finds annotations in generic parent (#7885)" do
        assert_type(%(
          annotation Ann
          end

          @[Ann(1)]
          class Parent(T)
          end

          class Child < Parent(Int32)
          end

          {{ Child.superclass.annotations(Ann)[0][0] }}
        )) { int32 }
      end

      it "find annotations on method parameters" do
        assert_type(%(
          annotation Foo; end
          annotation Bar; end

          class Moo
            def foo(@[Foo] @[Bar] value)
            end
          end

          {% if Moo.methods.first.args.first.annotations(Foo).size == 1 %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
      end
    end
  end

  describe "#annotation" do
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

    it "doesn't carry link annotation from lib to fun" do
      assert_no_errors <<-CRYSTAL
        @[Link("foo")]
        lib LibFoo
          fun foo
        end
        CRYSTAL
    end

    it "finds annotation in generic parent (#7885)" do
      assert_type(%(
        annotation Ann
        end

        @[Ann(1)]
        class Parent(T)
        end

        class Child < Parent(Int32)
        end

        {{ Child.superclass.annotation(Ann)[0] }}
      )) { int32 }
    end

    it "finds annotation on method arg" do
      assert_type(%(
        annotation Ann; end

        def foo(
          @[Ann] foo : Int32
        )
        end

        {% if @top_level.methods.find(&.name.==("foo")).args.first.annotation(Ann) %}
          1
        {% else %}
          'a'
        {% end %}
      )) { int32 }
    end

    it "finds annotation on method splat arg" do
      assert_type(%(
        annotation Ann; end

        def foo(
          id : Int32,
          @[Ann] *nums : Int32
        )
        end

        {% if @top_level.methods.find(&.name.==("foo")).args[1].annotation(Ann) %}
          1
        {% else %}
          'a'
        {% end %}
      )) { int32 }
    end

    it "finds annotation on method double splat arg" do
      assert_type(%(
        annotation Ann; end

        def foo(
          id : Int32,
          @[Ann] **nums
        )
        end

        {% if @top_level.methods.find(&.name.==("foo")).double_splat.annotation(Ann) %}
          1
        {% else %}
          'a'
        {% end %}
      )) { int32 }
    end

    it "finds annotation on an restricted method block arg" do
      assert_type(%(
        annotation Ann; end

        def foo(
          id : Int32,
          @[Ann] &block : Int32 ->
        )
          yield 10
        end

        {% if @top_level.methods.find(&.name.==("foo")).block_arg.annotation(Ann) %}
          1
        {% else %}
          'a'
        {% end %}
      )) { int32 }
    end
  end

  it "errors when annotate instance variable in subclass" do
    assert_error %(
      annotation Foo
      end

      class Base
        @x : Nil
      end

      class Child < Base
        @[Foo]
        @x : Nil
      end
      ),
      "can't annotate @x in Child because it was first defined in Base"
  end

  it "errors if wanting to add type inside annotation (1) (#8614)" do
    assert_error %(
      annotation Ann
      end

      class Ann::Foo
      end

      Ann::Foo.new
      ),
      "can't declare type inside annotation Ann"
  end

  it "errors if wanting to add type inside annotation (2) (#8614)" do
    assert_error %(
      annotation Ann
      end

      class Ann::Foo::Bar
      end

      Ann::Foo::Bar.new
      ),
      "can't declare type inside annotation Ann"
  end

  it "doesn't bleed annotation from class into class variable (#8314)" do
    assert_no_errors <<-CRYSTAL
      annotation Attr; end

      @[Attr]
      class Bar
        @@x = 0
      end
      CRYSTAL
  end
end
