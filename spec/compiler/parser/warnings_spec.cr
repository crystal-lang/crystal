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

describe "Parser warnings" do
  # CVE-2021-42574
  describe "Unicode bi-directional control characters" do
    ['\u202A', '\u202B', '\u202C', '\u202D', '\u202E', '\u2066', '\u2067', '\u2068', '\u2069'].each do |char|
      it { assert_parser_warning %(f#{char}), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %("#{char}"), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(\#{}#{char}), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %({{ "#{char}" }}), "Unescaped Unicode bi-directional control character: #{char.dump}" }

      it { assert_parser_warning %(:#{char}), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(:"#{char}"), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(def foo("#{char}" x); end), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(foo("#{char}": 1)), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %({"#{char}": 1}), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(NamedTuple("#{char}": Int32)), "Unescaped Unicode bi-directional control character: #{char.dump}" }

      it { assert_parser_warning %(%q(#{char})), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(%w(#{char})), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(%i(#{char})), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(%r(#{char})), "Unescaped Unicode bi-directional control character: #{char.dump}" }
      it { assert_parser_warning %(macro foo\n  #{char}\nend), "Unescaped Unicode bi-directional control character: #{char.dump}" }

      it { assert_no_parser_warning char.to_s.dump }
      it { assert_no_parser_warning char.dump }
    end

    # TODO: `SyntaxException#default_message` does not expose the column number yet
    pending "reports multiple warnings at correct positions" do
      parser = Parser.new(%("foo\u{202A}bar   \u{202B}baz"))
      parser.filename = "/test.cr"
      parser.parse

      warnings = parser.warnings.infos
      warnings.size.should eq(2)
      warnings[0].should match(/\b\/test.cr:1:5\b/)
      warnings[1].should match(/\b\/test.cr:1:12\b/)
    end
  end

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
end
