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

  it "stores doc for def when using ditto" do
    result = semantic %(
      class Foo
        # Hello
        def bar
        end

        # ditto
        def bar2
        end
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    bar = foo.lookup_defs("bar2").first
    bar.doc.should eq("Hello")
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

  it "stores doc for def with attribute" do
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

  it "stores doc for def with attribute" do
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
    bar = foo.metaclass.lookup_macros("bar").not_nil!.first
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
    foo = program.types["Foo"]
    foo.has_attribute?("Flags").should be_true
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
    ), wants_doc: true, inject_primitives: false
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for class if reopening" do
    result = semantic %(
      class Foo
      end

      # Hello
      class Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.not_nil!.size.should eq(2)
  end

  it "stores doc for module if reopening" do
    result = semantic %(
      module Foo
      end

      # Hello
      module Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores locations for auto-generated module" do
    result = semantic %(
      class Foo::Bar
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.locations.not_nil!.size.should eq(1)
  end
end
