require "../../spec_helper"

describe "Semantic: doc" do
  it "stores doc for class" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      class Foo
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for abstract class" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      abstract class Foo
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for struct" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      struct Foo
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for module" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      module Foo
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for def" do
    result = semantic <<-CRYSTAL, wants_doc: true
      class Foo
        # Hello
        def bar
        end
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  describe ":ditto:" do
    it "stores doc for const" do
      result = semantic <<-CRYSTAL, wants_doc: true
        # A number
        ONE = 1

        # :ditto:
        TWO = 2
        CRYSTAL
      program = result.program
      program.types["ONE"].doc.should eq "A number"
      program.types["TWO"].doc.should eq "A number"
    end

    it "stores doc for def" do
      result = semantic <<-CRYSTAL, wants_doc: true
        class Foo
          # Hello
          def bar
          end

          # :ditto:
          def bar2
          end
        end
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar2").first
      bar.doc.should eq("Hello")
    end

    it "stores doc for macro" do
      result = semantic <<-CRYSTAL, wants_doc: true
        # Hello
        macro bar
        end

        # :ditto:
        macro bar2
        end
        CRYSTAL
      program = result.program
      bar2 = program.lookup_macros("bar2").as(Array(Macro)).first
      bar2.doc.should eq("Hello")
    end

    it "amend previous doc" do
      result = semantic <<-CRYSTAL, wants_doc: true
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
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar2").first
      bar.doc.should eq("Hello\n\nWorld")
    end

    it "amend previous doc (without empty line)" do
      result = semantic <<-CRYSTAL, wants_doc: true
        class Foo
          # Hello
          def bar
          end

          # :ditto:
          # World
          def bar2
          end
        end
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar2").first
      bar.doc.should eq("Hello\n\nWorld")
    end

    it ":ditto: references last non-ditto doc" do
      result = semantic <<-CRYSTAL, wants_doc: true
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
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_defs("bar3").first
      bar.doc.should eq("Hello\n\nCrystal")
    end
  end

  it "stores doc for def with visibility" do
    result = semantic <<-CRYSTAL, wants_doc: true
      class Foo
        # Hello
        private def bar
        end
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  it "stores doc for def with annotation" do
    result = semantic <<-CRYSTAL, wants_doc: true
      class Foo
        # Hello
        @[AlwaysInline]
        def bar
        end
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  it "stores doc for def with annotation" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      @[AlwaysInline]
      fun bar : Int32
        1
      end
      CRYSTAL
    program = result.program
    bar = program.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  it "stores doc for abstract def" do
    result = semantic <<-CRYSTAL, wants_doc: true
      abstract class Foo
        # Hello
        abstract def bar
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")
  end

  {% for def_type in %w[def macro].map &.id %}
    it "overwrites doc for {{def_type}} when redefining" do
      result = semantic <<-CRYSTAL, wants_doc: true
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
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      bar = foo.lookup_{{def_type}}s("bar").as(Array).first
      bar.doc.should eq("Doc 2")
    end
  {% end %}

  it "stores doc for macro" do
    result = semantic <<-CRYSTAL, wants_doc: true
      class Foo
        # Hello
        macro bar
        end
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    bar = foo.metaclass.lookup_macros("bar").as(Array(Macro)).first
    bar.doc.should eq("Hello")
  end

  it "stores doc for fun def" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      fun foo : Int32
        1
      end
      CRYSTAL
    program = result.program
    foo = program.lookup_defs("foo").first
    foo.doc.should eq("Hello")
  end

  it "stores doc for enum" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      enum Foo
        A
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for flags enum with base type" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      @[Flags]
      enum Foo : UInt8
        A
      end
      CRYSTAL
    program = result.program
    ann = program.types["Flags"].as(Crystal::AnnotationType)
    foo = program.types["Foo"]
    foo.annotation(ann).should_not be_nil
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for enum and doesn't mix with value" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      enum Foo
        # World
        World
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for enum with @[Flags]" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      @[Flags]
      enum Foo
        A
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for enum member" do
    result = semantic <<-CRYSTAL, wants_doc: true
      enum Foo
        # Hello
        A = 1
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    a = foo.types["A"]
    a.doc.should eq("Hello")
    a.locations.not_nil!.size.should eq(1)
  end

  it "stores location for implicit flag enum members" do
    result = semantic <<-CRYSTAL, wants_doc: true
      @[Flags]
      enum Foo
        A = 1
        B = 2
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]

    a_loc = foo.types["All"].locations.should_not be_nil
    a_loc.should_not be_empty

    b_loc = foo.types["None"].locations.should_not be_nil
    b_loc.should_not be_empty
  end

  it "stores doc for constant" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      CONST = 1
      CRYSTAL
    program = result.program
    a = program.types["CONST"]
    a.doc.should eq("Hello")
    a.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for alias" do
    result = semantic <<-CRYSTAL, wants_doc: true
      # Hello
      alias Alias = Int32
      CRYSTAL
    program = result.program
    a = program.types["Alias"]
    a.doc.should eq("Hello")
    a.locations.not_nil!.size.should eq(1)
  end

  it "stores doc for nodes defined in macro call" do
    result = semantic <<-CRYSTAL, wants_doc: true
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
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]

    bar = foo.lookup_defs("bar").first
    bar.doc.should eq("Hello")

    bar_assign = foo.lookup_defs("bar=").first
    bar_assign.doc.should eq("Hello")
  end

  it "stores doc for nodes defined in macro call (2)" do
    result = semantic <<-CRYSTAL, wants_doc: true
      macro foo
        class Foo
        end
      end

      # Hello
      foo
      CRYSTAL
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
      result = semantic <<-CRYSTAL, wants_doc: true
        {{module_type}} Foo
          A = 1
        end

        # Hello
        {{module_type}} Foo
        end
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      foo.doc.should eq("Hello")
      foo.locations.not_nil!.size.should eq(2)
    end

    it "overwrites doc for {{module_type}} when reopening" do
      result = semantic <<-CRYSTAL, wants_doc: true
        # Doc 1
        {{module_type}} Foo
          A = 1
        end

        # Doc 2
        {{module_type}} Foo
        end

        {{module_type}} Foo
        end
        CRYSTAL
      program = result.program
      foo = program.types["Foo"]
      foo.doc.should eq("Doc 2")
    end
  {% end %}

  it "stores locations for auto-generated module" do
    result = semantic <<-CRYSTAL, wants_doc: true
      class Foo::Bar
      end
      CRYSTAL
    program = result.program
    foo = program.types["Foo"]
    foo.locations.not_nil!.size.should eq(1)
  end

  it "attaches doc in double macro expansion (#8463)" do
    result = semantic <<-CRYSTAL, wants_doc: true
      macro cls(nr)
        class MyClass{{nr}} end
      end

      macro cls2(nr)
        cls({{nr}})
      end

      # Some description
      cls2(1)
      CRYSTAL
    program = result.program
    type = program.types["MyClass1"]
    type.doc.should eq("Some description")
  end

  it "attaches doc to annotation in macro expansion (#9628)" do
    result = semantic <<-CRYSTAL, wants_doc: true
      macro ann
        annotation MyAnnotation
        end
      end

      # Some description
      ann
      CRYSTAL
    program = result.program
    type = program.types["MyAnnotation"]
    type.doc.should eq("Some description")
  end

  context "doc before annotation" do
    it "attached to struct/class" do
      result = semantic <<-CRYSTAL, wants_doc: true
        # Some description
        @[Packed]
        struct Foo
        end
        CRYSTAL
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to module" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        # Some description
        @[Ann]
        module Foo
        end
        CRYSTAL
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to enum" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        # Some description
        @[Ann]
        enum Foo
          One
        end
        CRYSTAL
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to constant" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        # Some description
        @[Ann]
        Foo = 1
        CRYSTAL
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to alias" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        # Some description
        @[Ann]
        alias Foo = Int32
        CRYSTAL
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to def" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        # Some description
        @[Ann]
        def foo
        end
        CRYSTAL
      program = result.program
      a_def = program.lookup_defs("foo").first
      a_def.doc.should eq("Some description")
    end

    it "attached to macro" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        # Some description
        @[Ann]
        macro foo
        end
        CRYSTAL
      program = result.program
      type = program.lookup_macros("foo").as(Array(Macro)).first
      type.doc.should eq("Some description")
    end

    it "attached to macro call" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        macro gen_type
          class Foo; end
        end

        # Some description
        @[Ann]
        gen_type
        CRYSTAL
      program = result.program
      type = program.types["Foo"]
      type.doc.should eq("Some description")
    end

    it "attached to macro call that produces multiple types" do
      result = semantic <<-CRYSTAL, wants_doc: true
        annotation Ann
        end

        class Foo
          macro getter(decl)
            @{{decl.var.id}} : {{decl.type.id}}

            def {{decl.var.id}} : {{decl.type.id}}
              @{{decl.var.id}}
            end
          end

          # Some description
          @[Ann]
          getter name : String?
        end
        CRYSTAL
      program = result.program
      a_def = program.types["Foo"].lookup_defs("name").first
      a_def.doc.should eq("Some description")
    end
  end
end
