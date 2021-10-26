require "../../../spec_helper"

describe Doc::Type do
  it "doesn't show types for alias type" do
    result = semantic(%(
      class Foo
        class Bar
        end
      end

      alias Alias = Foo

      Alias
    ))

    program = result.program

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
    result = semantic(%(
      class Foo
        def initialize(x)
        end
      end
    ))

    program = result.program

    generator = Doc::Generator.new program, [""]
    foo = generator.type(program.types["Foo"])
    foo.lookup_class_method("new").should_not be_nil
    foo.lookup_class_method("new", 1).should_not be_nil
  end

  describe "#node_to_html" do
    it "shows relative path" do
      program = semantic(<<-CODE).program
        class Foo
          class Bar
          end
        end
        CODE

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html("Bar".path).should eq(%(<a href="Foo/Bar.html">Bar</a>))
    end

    it "shows relative generic" do
      program = semantic(<<-CODE).program
        class Foo
          class Bar(T)
          end
        end
        CODE

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html(Generic.new("Bar".path, ["Foo".path] of ASTNode)).should eq(%(<a href="Foo/Bar.html">Bar</a>(<a href="Foo.html">Foo</a>)))
    end

    it "shows generic path with necessary colons" do
      program = semantic(<<-CODE).program
        class Foo
          class Foo
          end
        end
        CODE

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html("Foo".path(global: true)).should eq(%(<a href="Foo.html">::Foo</a>))
    end

    it "shows generic path with unnecessary colons" do
      program = semantic(<<-CODE).program
        class Foo
          class Bar
          end
        end
        CODE

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      foo.node_to_html("Foo".path(global: true)).should eq(%(<a href="Foo.html">Foo</a>))
    end

    it "shows tuples" do
      program = semantic(<<-CODE).program
        class Foo
        end

        class Bar
        end
        CODE

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      node = Generic.new("Tuple".path(global: true), ["Foo".path, "Bar".path] of ASTNode)
      foo.node_to_html(node).should eq(%(Tuple(<a href="Foo.html">Foo</a>, <a href="Bar.html">Bar</a>)))
    end

    it "shows named tuples" do
      program = semantic(<<-CODE).program
        class Foo
        end

        class Bar
        end
        CODE

      generator = Doc::Generator.new program, [""]
      foo = generator.type(program.types["Foo"])
      node = Generic.new("NamedTuple".path(global: true), [] of ASTNode, named_args: [NamedArgument.new("x", "Foo".path), NamedArgument.new("y", "Bar".path)])
      foo.node_to_html(node).should eq(%(NamedTuple(x: <a href="Foo.html">Foo</a>, y: <a href="Bar.html">Bar</a>)))
    end
  end

  it "ASTNode has no superclass" do
    program = semantic(<<-CODE).program
      module Crystal
        module Macros
          class ASTNode
          end
          class Arg < ASTNode
          end
        end
      end
      CODE

    generator = Doc::Generator.new program, [""]
    macros_module = program.types["Crystal"].types["Macros"]
    astnode = generator.type(macros_module.types["ASTNode"])
    astnode.superclass.should eq(nil)
    # Sanity check: subclasses of ASTNode has the right superclass
    generator.type(macros_module.types["Arg"]).superclass.should eq(astnode)
  end

  it "ASTNode has no ancestors" do
    program = semantic(<<-CODE).program
      module Crystal
        module Macros
          class ASTNode
          end
          class Arg < ASTNode
          end
        end
      end
      CODE

    generator = Doc::Generator.new program, [""]
    macros_module = program.types["Crystal"].types["Macros"]
    astnode = generator.type(macros_module.types["ASTNode"])
    astnode.ancestors.empty?.should be_true
    # Sanity check: subclasses of ASTNode has the right ancestors
    generator.type(macros_module.types["Arg"]).ancestors.should eq([astnode])
  end
end
