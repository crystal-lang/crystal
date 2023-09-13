require "../../spec_helper"

describe "Semantic: doc" do
  it "stores doc for class" do
    result = semantic %(
      # Hello
      class Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for abstract class" do
    result = semantic %(
      # Hello
      abstract class Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for struct" do
    result = semantic %(
      # Hello
      struct Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for module" do
    result = semantic %(
      # Hello
      module Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for def" do
    result = semantic %(
      class Foo
        # Hello
        def bar
        end
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  describe ":ditto:" do
    it "stores doc for const" do
      result = semantic %(
        # A number
        ONE = 1

        # :ditto:
        TWO = 2
      ), wants_doc: true
      program = result.program
      program.types["ONE"].doc.should eq "A number"
      program.types["TWO"].doc.should eq "A number"
    end

    it "stores doc for def" do
      result = semantic %(
        class Foo
          # Hello
          def bar
          end

          # :ditto:
          def bar2
          end
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar2").first
      bar.doc.should eq("Hello")
    end

    it "stores doc for macro" do
      result = semantic %(
        # Hello
        macro bar
        end

        # :ditto:
        macro bar2
        end
      ), wants_doc: true
      program = result.program
      bar2 = program.lookup_macros("bar2").as(Array(Macro)).first
      bar2.doc.should eq("Hello")
    end

    it "amend previous doc" do
      result = semantic %(
        class Foo
          # Hello
          def bar
          end

          # :ditto:
          #
          # World
          def bar2
          end
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar2").first
      bar.doc.should eq("Hello\n\nWorld")
    end

    it "amend previous doc (without empty line)" do
      result = semantic %(
        class Foo
          # Hello
          def bar
          end

          # :ditto:
          # World
          def bar2
          end
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar2").first
      bar.doc.should eq("Hello\n\nWorld")
    end

    it ":ditto: references last non-ditto doc" do
      result = semantic %(
        class Foo
          # Hello
          def bar
          end

          # :ditto:
          #
          # World
          def bar2
          end

          # :ditto:
          #
          # Crystal
          def bar3
          end
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar3").first
      bar.doc.should eq("Hello\n\nCrystal")
    end
  end

  it "stores doc for def with visibility" do
    result = semantic %(
      class Foo
        # Hello
        private def bar
        end
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  it "stores doc for def with annotation" do
    result = semantic %(
      class Foo
        # Hello
        @[AlwaysInline]
        def bar
        end
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  it "stores doc for def with annotation" do
    result = semantic %(
      # Hello
      @[AlwaysInline]
      fun bar : Int32
        1
      end
    ), wants_doc: true
    program = result.program
    bar = program.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  it "stores doc for abstract def" do
    result = semantic %(
      abstract class Foo
        # Hello
        abstract def bar
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  {% for def_type in %w[def macro].map &.id %}
    it "overwrites doc for {{def_type}} when redefining" do
      result = semantic %(
        module Foo
          # Doc 1
          {{def_type}} bar
          end
        end

        module Foo
          # Doc 2
          {{def_type}} bar
          end
        end

        module Foo
          {{def_type}} bar
          end
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_{{def_type}}s("bar").as(Array).first
      bar.doc.should eq("Doc 2")
    end
  {% end %}

  it "stores doc for macro" do
    result = semantic %(
      class Foo
        # Hello
        macro bar
        end
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    bar = foo.metaclass.lookup_macros("bar").as(Array(Macro)).first
    bar.doc.should eq("Hello")
  end

  it "stores doc for fun def" do
    result = semantic %(
      # Hello
      fun foo : Int32
        1
      end
    ), wants_doc: true
    program = result.program
    foo = program.lookup_defs("foo").first
    foo.doc.should eq("Hello")
  end

  it "stores doc for enum" do
    result = semantic %(
      # Hello
      enum Foo
        A
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for flags enum with base type" do
    result = semantic %(
      # Hello
      @[Flags]
      enum Foo : UInt8
        A
      end
    ), wants_doc: true
    program = result.program
    ann = program.types["Flags"].as(Crystal::AnnotationType)
    foo = program.types["Foo"]
    foo.annotation(ann).should_not be_nil
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for enum and doesn't mix with value" do
    result = semantic %(
      # Hello
      enum Foo
        # World
        World
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for enum with @[Flags]" do
    result = semantic %(
      # Hello
      @[Flags]
      enum Foo
        A
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for enum member" do
    result = semantic %(
      enum Foo
        # Hello
        A = 1
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    a = foo.types["A"]
    a.doc.should eq("Hello")
    a.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for constant" do
    result = semantic %(
      # Hello
      CONST = 1
    ), wants_doc: true
    program = result.program
    a = program.types["CONST"]
    a.doc.should eq("Hello")
    a.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for alias" do
    result = semantic %(
      # Hello
      alias Alias = Int32
    ), wants_doc: true
    program = result.program
    a = program.types["Alias"]
    a.doc.should eq("Hello")
    a.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for nodes defined in macro call" do
    result = semantic %(
      class Object
        macro property(name)
          def {{name}}=(@{{name}})
          end

          def {{name}}
            @{{name}}
          end
        end
      end

      class Foo
        # Hello
        property bar
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]

    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")

    bar_assign = foo.lookup_defs("bar=").first
    bar_assign.doc.should eq("Hello")
  end

  it "stores doc for nodes defined in macro call (2)" do
    result = semantic %(
      macro foo
        class Foo
        end
      end

      # Hello
      foo
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for macro defined in macro call" do
    result = semantic <<-CRYSTAL, wants_doc: true
      macro def_foo
        macro foo
        end
      end

      # Hello
      def_foo
      CRYSTAL
    program = result.program
    foo = program.macros.not_nil!["foo"].first
    foo.doc.should eq("Hello")
  end

  {% for module_type in %w[class struct module enum].map &.id %}
    it "stores doc for {{module_type}} when reopening" do
      result = semantic %(
        {{module_type}} Foo
          A = 1
        end

        # Hello
        {{module_type}} Foo
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      foo.doc.should eq("Hello")
      foo.locations.not_nil!.size.should eq(2)
    end

    it "overwrites doc for {{module_type}} when reopening" do
      result = semantic %(
        # Doc 1
        {{module_type}} Foo
          A = 1
        end

        # Doc 2
        {{module_type}} Foo
        end

        {{module_type}} Foo
        end
      ), wants_doc: true
      program = result.program
      foo = program.types["Foo"]
      foo.doc.should eq("Doc 2")
    end
  {% end %}

  it "stores locations for auto-generated module" do
    result = semantic %(
      class Foo::Bar
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.locations.not_nil!.size.should eq(1)
  end

  it "attaches doc in double macro expansion (#8463)" do
    result = semantic %(
      macro cls(nr)
        class MyClass{{nr}} end
      end

      macro cls2(nr)
        cls({{nr}})
      end

      # Some description
      cls2(1)
    ), wants_doc: true
    program = result.program
    type = program.types["MyClass1"]
    type.doc.should eq("Some description")
  end

  it "attaches doc to annotation in macro expansion (#9628)" do
    result = semantic %(
      macro ann
        annotation MyAnnotation
        end
      end

      # Some description
      ann
    ), wants_doc: true
    program = result.program
    type = program.types["MyAnnotation"]
    type.doc.should eq("Some description")
  end

  context "doc before annotation" do
    it "attached to struct/class" do
      result = semantic %(
        # Some description
        @[Packed]
        struct Foo
        end
      ), wants_doc: true
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to module" do
      result = semantic %(
        annotation Ann
        end

        # Some description
        @[Ann]
        module Foo
        end
      ), wants_doc: true
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to enum" do
      result = semantic %(
        annotation Ann
        end

        # Some description
        @[Ann]
        enum Foo
          One
        end
      ), wants_doc: true
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to constant" do
      result = semantic %(
        annotation Ann
        end

        # Some description
        @[Ann]
        Foo = 1
      ), wants_doc: true
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to alias" do
      result = semantic %(
        annotation Ann
        end

        # Some description
        @[Ann]
        alias Foo = Int32
      ), wants_doc: true
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to def" do
      result = semantic %(
        annotation Ann
        end

        # Some description
        @[Ann]
        def foo
        end
      ), wants_doc: true
      program = result.program
      a_def = program.lookup_defs("foo").first
      a_def.doc.should eq("Some description")
    end

    it "attached to macro" do
      result = semantic %(
        annotation Ann
        end

        # Some description
        @[Ann]
        macro foo
        end
      ), wants_doc: true
      program = result.program
      type = program.lookup_macros("foo").as(Array(Macro)).first
      type.doc.should eq("Some description")
    end
  end
end
