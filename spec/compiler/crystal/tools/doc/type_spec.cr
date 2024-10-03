require "../../../spec_helper"

describe Doc::Type do
  it "doesn't show types for alias type" do
    program = top_level_semantic(<<-CRYSTAL, wants_doc: true).program
      class Foo
        class Bar
        end
      end

      alias Alias = Foo

      Alias
      CRYSTAL

    # Set locations to types relative to the included dir
    # so they are included by the doc generator
    foo_bar_type = program.types["Foo"].types["Bar"]
    foo_bar_type.add_location(Location.new("./foo.cr", 1, 1))

    alias_type = program.types["Alias"]
    alias_type.add_location(Location.new("./foo.cr", 1, 1))

    generator = Doc::Generator.new program, ["."]

    doc_alias_type = generator.type(alias_type)
    doc_alias_type.types.size.should eq(0)
  end

  it "finds construct when searching class method (#8095)" do
    program = top_level_semantic(<<-CRYSTAL, wants_doc: true).program
      class Foo
        def initialize(x)
        end
      end
      CRYSTAL

    generator = Doc::Generator.new program, [""]
    foo = generator.type(program.types["Foo"])
    foo.lookup_class_method("new").should_not be_nil
    foo.lookup_class_method("new", 1).should_not be_nil
  end

  describe "#node_to_html" do
    it "shows relative path" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          class Bar
          end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html("Bar".path).should eq(%(<a href="Foo/Bar.html">Bar</a>))
    end

    it "shows relative generic" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          class Bar(T)
          end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html(Generic.new("Bar".path, ["Foo".path] of ASTNode)).should eq(%(<a href="Foo/Bar.html">Bar</a>(<a href="Foo.html">Foo</a>)))
    end

    it "shows generic path with necessary colons" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          class Foo
          end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html("Foo".path(global: true)).should eq(%(<a href="Foo.html">::Foo</a>))
    end

    it "shows generic path with unnecessary colons" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          class Bar
          end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html("Foo".path(global: true)).should eq(%(<a href="Foo.html">Foo</a>))
    end

    it "shows tuples" do
      program = semantic(<<-CRYSTAL).program
        class Foo
        end

        class Bar
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      node = Generic.new("Tuple".path(global: true), ["Foo".path, "Bar".path] of ASTNode)
      foo.node_to_html(node).should eq(%(Tuple(<a href="Foo.html">Foo</a>, <a href="Bar.html">Bar</a>)))
    end

    it "shows named tuples" do
      program = semantic(<<-CRYSTAL).program
        class Foo
        end

        class Bar
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      node = Generic.new("NamedTuple".path(global: true), [] of ASTNode, named_args: [NamedArgument.new("x", "Foo".path), NamedArgument.new("y", "Bar".path)])
      foo.node_to_html(node).should eq(%(NamedTuple(x: <a href="Foo.html">Foo</a>, y: <a href="Bar.html">Bar</a>)))
    end
  end

  it "ASTNode has no superclass" do
    program = semantic(<<-CRYSTAL).program
      module Crystal
        module Macros
          class ASTNode
          end
          class Arg < ASTNode
          end
        end
      end
      CRYSTAL

    generator = Doc::Generator.new program, [""]
    macros_module = program.types["Crystal"].types["Macros"]
    astnode = generator.type(macros_module.types["ASTNode"])
    astnode.superclass.should eq(nil)
    # Sanity check: subclasses of ASTNode has the right superclass
    generator.type(macros_module.types["Arg"]).superclass.should eq(astnode)
  end

  it "ASTNode has no ancestors" do
    program = semantic(<<-CRYSTAL).program
      module Crystal
        module Macros
          class ASTNode
          end
          class Arg < ASTNode
          end
        end
      end
      CRYSTAL

    generator = Doc::Generator.new program, [""]
    macros_module = program.types["Crystal"].types["Macros"]
    astnode = generator.type(macros_module.types["ASTNode"])
    astnode.ancestors.should be_empty
    # Sanity check: subclasses of ASTNode has the right ancestors
    generator.type(macros_module.types["Arg"]).ancestors.should eq([astnode])
  end

  describe "#instance_methods" do
    it "sorts operators first" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          def foo; end
          def ~; end
          def +; end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.instance_methods.map(&.name).should eq ["+", "~", "foo"]
    end
  end

  describe "#class_methods" do
    it "sorts operators first" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          def self.foo; end
          def self.~; end
          def self.+; end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.class_methods.map(&.name).should eq ["+", "~", "foo"]
    end
  end

  describe "#macros" do
    it "sorts operators first" do
      program = semantic(<<-CRYSTAL).program
        class Foo
          macro foo; end
          macro ~; end
          macro +; end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.macros.map(&.name).should eq ["+", "~", "foo"]
    end
  end

  describe "#subclasses" do
    it "only include types with docs" do
      program = semantic(<<-CRYSTAL, wants_doc: true).program
        class Foo
        end

        class Bar < Foo
        end

        # :nodoc:
        class Baz < Foo
        end

        module Mod1
          class Bar < ::Foo
          end
        end

        # :nodoc:
        module Mod2
          class Baz < ::Foo
          end
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.subclasses.map(&.full_name).should eq ["Bar", "Mod1::Bar"]
    end
  end

  describe "#ancestors" do
    it "only include types with docs" do
      program = semantic(<<-CRYSTAL, wants_doc: true).program
        # :nodoc:
        module Mod3
          class Baz
          end
        end

        class Mod2::Baz < Mod3::Baz
        end

        module Mod1
          # :nodoc:
          class Baz < Mod2::Baz
          end
        end

        class Baz < Mod1::Baz
        end

        class Foo < Baz
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.ancestors.map(&.full_name).should eq ["Baz", "Mod2::Baz"]
    end
  end

  describe "#included_modules" do
    it "only include types with docs" do
      program = semantic(<<-CRYSTAL, wants_doc: true).program
        # :nodoc:
        module Mod3
          module Baz
          end
        end

        module Mod2
          # :nodoc:
          module Baz
          end
        end

        module Mod1
          module Baz
          end
        end

        module Baz
        end

        class Foo
          include Baz
          include Mod1::Baz
          include Mod2::Baz
          include Mod3::Baz
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.included_modules.map(&.full_name).should eq ["Baz", "Mod1::Baz"]
    end
  end

  describe "#extended_modules" do
    it "only include types with docs" do
      program = semantic(<<-CRYSTAL, wants_doc: true).program
        # :nodoc:
        module Mod3
          module Baz
          end
        end

        module Mod2
          # :nodoc:
          module Baz
          end
        end

        module Mod1
          module Baz
          end
        end

        module Baz
        end

        class Foo
          extend Baz
          extend Mod1::Baz
          extend Mod2::Baz
          extend Mod3::Baz
        end
        CRYSTAL

      generator = Doc::Generator.new program, [""]
      type = generator.type(program.types["Foo"])
      type.extended_modules.map(&.full_name).should eq ["Baz", "Mod1::Baz"]
    end
  end
end
