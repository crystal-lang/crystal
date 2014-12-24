require "../../spec_helper"

describe "Type inference: doc" do
  it "stores doc for class" do
    result = infer_type %(
      # Hello
      class Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.length.should eq(1)
  end

  it "stores doc for abstract class" do
    result = infer_type %(
      # Hello
      abstract class Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for struct" do
    result = infer_type %(
      # Hello
      struct Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.length.should eq(1)
  end

  it "stores doc for module" do
    result = infer_type %(
      # Hello
      module Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.length.should eq(1)
  end

  it "stores doc for def" do
    result = infer_type %(
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

  it "stores doc for def with visibility" do
    result = infer_type %(
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
    result = infer_type %(
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

  it "stores doc for abstract def" do
    result = infer_type %(
      class Foo
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
    result = infer_type %(
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
    result = infer_type %(
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
    result = infer_type %(
      # Hello
      enum Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.length.should eq(1)
  end

  it "stores doc for enum with @[Flags]" do
    result = infer_type %(
      # Hello
      @[Flags]
      enum Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
  end

  it "stores doc for enum member" do
    result = infer_type %(
      enum Foo
        # Hello
        A = 1
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    a = foo.types["A"]
    a.doc.should eq("Hello")
  end

  it "stores doc for constant" do
    result = infer_type %(
      # Hello
      A = 1
    ), wants_doc: true
    program = result.program
    a = program.types["A"]
    a.doc.should eq("Hello")
  end

  it "stores doc for alias" do
    result = infer_type %(
      # Hello
      alias A = Int32
    ), wants_doc: true
    program = result.program
    a = program.types["A"]
    a.doc.should eq("Hello")
    a.locations.length.should eq(1)
  end

  it "stores doc for nodes defined in macro call" do
    result = infer_type %(
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
    result = infer_type %(
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

  it "stores doc for class if reopening" do
    result = infer_type %(
      class Foo
      end

      # Hello
      class Foo
      end
    ), wants_doc: true
    program = result.program
    foo = program.types["Foo"]
    foo.doc.should eq("Hello")
    foo.locations.length.should eq(2)
  end

  it "stores doc for module if reopening" do
    result = infer_type %(
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
end
