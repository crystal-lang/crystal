require "spec"
require "http/client"
require "spec/helpers/string"

UCD_ROOT = "http://www.unicode.org/Public/#{Unicode::VERSION}/ucd/"

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

private macro assert_prints_codepoints(call, str, desc, *, file = __FILE__, line = __LINE__)
  %expectation = CodepointsEqualExpectation.new(({{ str }}).as(String), {{ desc }})
  assert_prints({{ call }}, should: %expectation, file: {{ file }}, line: {{ line }})
end

private def assert_normalized(source, target, form : Unicode::NormalizationForm, *, file = __FILE__, line = __LINE__)
  normalized = source.unicode_normalized?(form)
  equal = (source == target)
  return if normalized == equal

  got = source.codepoints.join(", ") { |x| "U+%04X" % x }
  kind = form.to_s.upcase
  if equal # !normalized
    fail <<-ERROR, file: file, line: line
      Expected: is#{kind}(str) == false
           got: str == to#{kind}(str)
                str == [#{got}]"
      ERROR
  else # !equal && normalized
    expected = target.codepoints.join(", ") { |x| "U+%04X" % x }
    fail <<-ERROR, file: file, line: line
      Expected: is#{kind}(str) == true
           got: str != to#{kind}(str)
                str == [#{got}]
                to#{kind}(str) == [#{expected}]"
      ERROR
  end
end

private def assert_normalizes(source, nfc_str, nfd_str, nfkc_str, nfkd_str, *, file = __FILE__, line = __LINE__)
  assert_normalized source, nfc_str, :nfc, file: file, line: line
  assert_normalized source, nfd_str, :nfd, file: file, line: line
  assert_normalized source, nfkc_str, :nfkc, file: file, line: line
  assert_normalized source, nfkd_str, :nfkd, file: file, line: line

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
    context "official test cases" do
      url = "#{UCD_ROOT}NormalizationTest.txt"
      body = HTTP::Client.get(url).body
      body.each_line do |line|
        line = line.strip
        next if line.empty?
        next if line.starts_with?('#') || line.starts_with?('@')

        it line do
          pieces = line.split(';', limit: 6)
          (0..4).each do |i|
            pieces[i] = pieces[i].split(' ').join &.to_i(16).chr
          end
          assert_normalizes pieces[0], pieces[1], pieces[2], pieces[3], pieces[4]
        end
      end
    end
  end
end
