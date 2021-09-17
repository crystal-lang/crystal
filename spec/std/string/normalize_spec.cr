require "spec"
require "http/client"
require "../../support/string"

UCD_ROOT = "http://www.unicode.org/Public/13.0.0/ucd/"

private struct CodepointsEqualExpectation
  @expected_value : Array(Int32)

  def initialize(str : String, @desc : String)
    @expected_value = str.codepoints
  end

  def match(actual_value)
    @expected_value == actual_value.codepoints
  end

  def failure_message(actual_value)
    expected = @expected_value.join(", ") { |x| "U+%04X" % x }
    got = actual_value.codepoints.join(", ") { |x| "U+%04X" % x }
    "While testing #{@desc}:\nexpected: [#{expected}]\n     got: [#{got}]"
  end

  def negative_failure_message(actual_value)
    expected = @expected_value.join(", ") { |x| "U+%04X" % x }
    "While testing #{@desc}:\nexpected: actual_value.codepoints != [#{expected}]"
  end
end

# same as `assert_prints`, but uses `CodepointsEqualExpectation` instead of `eq`
private macro assert_prints_codepoints(call, str, desc, *, file = __FILE__, line = __LINE__)
  %str = ({{ str }}).as(String)
  %file = {{ file }}
  %line = {{ line }}
  %expectation = CodepointsEqualExpectation.new(%str, {{ desc }})

  %result = {{ call }}
  %result.should be_a(String), file: %file, line: %line
  %result.should %expectation, file: %file, line: %line

  String.build do |io|
    {% if call.receiver %}{{ call.receiver }}.{% end %}{{ call.name }}(
      io,
      {% for arg in call.args %} {{ arg }}, {% end %}
      {% if call.named_args %} {% for narg in call.named_args %} {{ narg.name }}: {{ narg.value }}, {% end %} {% end %}
    ) {{ call.block }}
  end.should %expectation, file: %file, line: %line

  {% unless flag?(:win32) %}
    string_build_via_utf16 do |io|
      {% if call.receiver %}{{ call.receiver }}.{% end %}{{ call.name }}(
        io,
        {% for arg in call.args %} {{ arg }}, {% end %}
        {% if call.named_args %} {% for narg in call.named_args %} {{ narg.name }}: {{ narg.value }}, {% end %} {% end %}
      ) {{ call.block }}
    end.should %expectation, file: %file, line: %line
  {% end %}
end

private def assert_normalizes(source, nfc_str, nfd_str, nfkc_str, nfkd_str, *, file = __FILE__, line = __LINE__)
  assert_prints_codepoints source.unicode_normalize(:nfc), nfc_str, "c2 == toNFC(c1)", file: file, line: line
  assert_prints_codepoints nfc_str.unicode_normalize(:nfc), nfc_str, "c2 == toNFC(c2)", file: file, line: line
  assert_prints_codepoints nfd_str.unicode_normalize(:nfc), nfc_str, "c2 == toNFC(c3)", file: file, line: line
  assert_prints_codepoints nfkc_str.unicode_normalize(:nfc), nfkc_str, "c4 == toNFC(c4)", file: file, line: line
  assert_prints_codepoints nfkd_str.unicode_normalize(:nfc), nfkc_str, "c4 == toNFC(c5)", file: file, line: line

  assert_prints_codepoints source.unicode_normalize(:nfd), nfd_str, "c3 == toNFD(c1)", file: file, line: line
  assert_prints_codepoints nfc_str.unicode_normalize(:nfd), nfd_str, "c3 == toNFD(c2)", file: file, line: line
  assert_prints_codepoints nfd_str.unicode_normalize(:nfd), nfd_str, "c3 == toNFD(c3)", file: file, line: line
  assert_prints_codepoints nfkc_str.unicode_normalize(:nfd), nfkd_str, "c5 == toNFD(c4)", file: file, line: line
  assert_prints_codepoints nfkd_str.unicode_normalize(:nfd), nfkd_str, "c5 == toNFD(c5)", file: file, line: line

  assert_prints_codepoints source.unicode_normalize(:nfkc), nfkc_str, "c4 == toNFKC(c1)", file: file, line: line
  assert_prints_codepoints nfc_str.unicode_normalize(:nfkc), nfkc_str, "c4 == toNFKC(c2)", file: file, line: line
  assert_prints_codepoints nfd_str.unicode_normalize(:nfkc), nfkc_str, "c4 == toNFKC(c3)", file: file, line: line
  assert_prints_codepoints nfkc_str.unicode_normalize(:nfkc), nfkc_str, "c4 == toNFKC(c4)", file: file, line: line
  assert_prints_codepoints nfkd_str.unicode_normalize(:nfkc), nfkc_str, "c4 == toNFKC(c5)", file: file, line: line

  assert_prints_codepoints source.unicode_normalize(:nfkd), nfkd_str, "c5 == toNFKD(c1)", file: file, line: line
  assert_prints_codepoints nfc_str.unicode_normalize(:nfkd), nfkd_str, "c5 == toNFKD(c2)", file: file, line: line
  assert_prints_codepoints nfd_str.unicode_normalize(:nfkd), nfkd_str, "c5 == toNFKD(c3)", file: file, line: line
  assert_prints_codepoints nfkc_str.unicode_normalize(:nfkd), nfkd_str, "c5 == toNFKD(c4)", file: file, line: line
  assert_prints_codepoints nfkd_str.unicode_normalize(:nfkd), nfkd_str, "c5 == toNFKD(c5)", file: file, line: line
end

describe String do
  describe "#unicode_normalize" do
    it "official test cases" do
      url = "#{UCD_ROOT}NormalizationTest.txt"
      body = HTTP::Client.get(url).body
      body.each_line do |line|
        line = line.strip
        next if line.empty?
        next if line.starts_with?('#') || line.starts_with?('@')

        pieces = line.split(';', limit: 6)
        (0..4).each do |i|
          pieces[i] = pieces[i].split(' ').join &.to_i(16).chr
        end
        assert_normalizes pieces[0], pieces[1], pieces[2], pieces[3], pieces[4]
      end
    end
  end
end
