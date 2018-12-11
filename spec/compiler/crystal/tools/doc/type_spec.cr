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

    generator = Doc::Generator.new program, ["."], ".", "html", nil

    doc_alias_type = generator.type(alias_type)
    doc_alias_type.types.size.should eq(0)
  end
end
