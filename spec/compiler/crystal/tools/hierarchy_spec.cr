require "../../../spec_helper"

private def assert_text_hierarchy(source, filter, expected, *, file = __FILE__, line = __LINE__)
  program = semantic(source).program
  output = String.build { |io| Crystal.print_hierarchy(program, io, filter, "text") }
  output.should eq(expected), file: file, line: line
end

private def assert_json_hierarchy(source, filter, expected, *, file = __FILE__, line = __LINE__)
  program = semantic(source).program
  output = String.build { |io| Crystal.print_hierarchy(program, io, filter, "json") }
  JSON.parse(output).should eq(JSON.parse(expected)), file: file, line: line
end

describe Crystal::TextHierarchyPrinter do
  it "works" do
    assert_text_hierarchy <<-CRYSTAL, "ar$", <<-EOS
      class Foo
      end

      class Bar < Foo
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- class Reference (4 bytes)
           |
           +- class Foo (4 bytes)
              |
              +- class Bar (4 bytes)\n
      EOS
  end

  it "shows correct size for Bool member" do
    assert_text_hierarchy <<-CRYSTAL, "Foo", <<-EOS
      struct Foo
        @x = true
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- struct Value (0 bytes)
           |
           +- struct Struct (0 bytes)
              |
              +- struct Foo (1 bytes)
                     @x : Bool (1 bytes)\n
      EOS
  end
end

describe Crystal::JSONHierarchyPrinter do
  it "works" do
    assert_json_hierarchy <<-CRYSTAL, "ar$", <<-JSON
      class Foo
      end

      class Bar < Foo
      end
      CRYSTAL
      {
        "name": "Object",
        "kind": "class",
        "size_in_bytes": 4,
        "sub_types": [
          {
            "name": "Reference",
            "kind": "class",
            "size_in_bytes": 4,
            "sub_types": [
              {
                "name": "Foo",
                "kind": "class",
                "size_in_bytes": 4,
                "sub_types": [
                  {
                    "name": "Bar",
                    "kind": "class",
                    "size_in_bytes": 4,
                    "sub_types": []
                  }
                ]
              }
            ]
          }
        ]
      }
      JSON
  end
end
