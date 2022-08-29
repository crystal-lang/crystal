require "../../support/syntax"

private def assert_parser_warning(source, message, *, file = __FILE__, line = __LINE__)
  parser = Parser.new(source)
  parser.filename = "/foo/bar/baz.cr"
  node = parser.parse

  warnings = parser.warnings.infos
  warnings.size.should eq(1), file: file, line: line
  warnings[0].should contain(message), file: file, line: line
end

describe "Parser warnings" do
  it "warns on suffix-less UInt64 literals > Int64::MAX" do
    values = [
      "9223372036854775808",  # Int64::MAX + 1
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
end
