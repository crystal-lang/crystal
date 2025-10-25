require "../../support/syntax"

private def assert_parser_warning(source, message, *, file = __FILE__, line = __LINE__)
  parser = Parser.new(source)
  parser.filename = "/test.cr"
  parser.parse

  warnings = parser.warnings.infos
  warnings.size.should eq(1), file: file, line: line
  warnings[0].should contain(message), file: file, line: line
end

private def assert_no_parser_warning(source, *, file = __FILE__, line = __LINE__)
  parser = Parser.new(source)
  parser.filename = "/test.cr"
  parser.parse

  warnings = parser.warnings.infos
  warnings.should eq([] of String), file: file, line: line
end

VALID_SIGILS = ['i', 'q', 'r', 'w', 'x', 'Q']

describe "Parser warnings" do
  it "warns on suffix-less UInt64 literals > Int64::MAX" do
    values = [
      "9223372036854775808", # Int64::MAX + 1
      "9999999999999999999",
      "10000000000000000000",
      "18446744073709551615", # UInt64::MAX
      "0x8000_0000_0000_0000",
      "0xFFFF_FFFF_FFFF_FFFF",
    ]

    values.each do |value|
      assert_parser_warning value, "Warning: #{value} doesn't fit in an Int64, try using the suffix u64 or i128"
      assert_parser_warning "Foo(#{value})", "Warning: #{value} doesn't fit in an Int64, try using the suffix u64 or i128"
      assert_parser_warning "{{ #{value} }}", "Warning: #{value} doesn't fit in an Int64, try using the suffix u64 or i128"
    end
  end

  describe "warns on missing space before colon" do
    it "in block param type restriction" do
      assert_parser_warning("def foo(&block: Foo)\nend", "warning in /test.cr:1\nWarning: space required before colon in type restriction (run `crystal tool format` to fix this)")
      assert_no_parser_warning("def foo(&block : Foo)\nend")
      assert_no_parser_warning("def foo(&@foo)\nend")
    end

    it "in anonymous block param type restriction" do
      assert_parser_warning("def foo(&: Foo)\nend", "warning in /test.cr:1\nWarning: space required before colon in type restriction (run `crystal tool format` to fix this)")
      assert_no_parser_warning("def foo(& : Foo)\nend")
      assert_no_parser_warning("def foo(&)\nend")
    end

    it "in type declaration" do
      assert_parser_warning("x: Int32", "warning in /test.cr:1\nWarning: space required before colon in type declaration (run `crystal tool format` to fix this)")
      assert_no_parser_warning("x : Int32")
      assert_parser_warning("class Foo\n@x: Int32\nend", "warning in /test.cr:2\nWarning: space required before colon in type declaration (run `crystal tool format` to fix this)")
      assert_no_parser_warning("class Foo\n@x : Int32\nend")
      assert_parser_warning("class Foo\n@@x: Int32\nend", "warning in /test.cr:2\nWarning: space required before colon in type declaration (run `crystal tool format` to fix this)")
      assert_no_parser_warning("class Foo\n@@x : Int32\nend")
    end

    it "in return type restriction" do
      assert_parser_warning("def foo: Foo\nend", "warning in /test.cr:1\nWarning: space required before colon in return type restriction (run `crystal tool format` to fix this)")
      assert_no_parser_warning("def foo : Foo\nend")
    end
  end

  it "warns on single-letter macro fresh variables with indices" do
    chars = ('A'..'Z').to_a + ('a'..'z').to_a - VALID_SIGILS
    chars.each do |letter|
      assert_parser_warning <<-CRYSTAL, "Warning: single-letter macro fresh variables with indices are deprecated"
        macro foo
          %#{letter}{1} = 2
        end
        CRYSTAL
    end
  end

  it "doesn't warn on sigils that resemble single-letter macro fresh variables with indices" do
    VALID_SIGILS.each do |letter|
      assert_no_parser_warning <<-CRYSTAL
        macro foo
          %#{letter}{1}
        end
        CRYSTAL
    end
  end

  it "doesn't warn on single-letter macro fresh variables without indices" do
    ('A'..'Z').each do |letter|
      assert_no_parser_warning <<-CRYSTAL
        macro foo
          %#{letter} = 1
          %#{letter.downcase} = 2
        end
        CRYSTAL
    end
  end
end
