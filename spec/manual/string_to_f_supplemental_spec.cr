# Runs the fast_float supplemental test suite:
# https://github.com/fastfloat/supplemental_test_files
#
#   Supplemental data files for testing floating parsing (credit: Nigel Tao for
#   the data)
#
#   LICENSE file (Apache 2): https://github.com/nigeltao/parse-number-fxx-test-data/blob/main/LICENSE
#
# Due to the sheer volume of the test cases (5.2+ million test cases across
# 270+ MB of text) these specs are not vendored into the Crystal repository.

require "spec"
require "http/client"
require "../support/number"
require "wait_group"

# these specs permit underflow and overflow to return 0 and infinity
# respectively (when `ret.rc == Errno::ERANGE`), so we have to use
# `Float::FastFloat` directly
def fast_float_to_f32(str)
  value = uninitialized Float32
  start = str.to_unsafe
  finish = start + str.bytesize
  options = Float::FastFloat::ParseOptionsT(typeof(str.to_unsafe.value)).new(format: :general)

  ret = Float::FastFloat::BinaryFormat_Float32.new.from_chars_advanced(start, finish, pointerof(value), options)
  {Errno::NONE, Errno::ERANGE}.should contain(ret.ec)
  value
end

def fast_float_to_f64(str)
  value = uninitialized Float64
  start = str.to_unsafe
  finish = start + str.bytesize
  options = Float::FastFloat::ParseOptionsT(typeof(str.to_unsafe.value)).new(format: :general)

  ret = Float::FastFloat::BinaryFormat_Float64.new.from_chars_advanced(start, finish, pointerof(value), options)
  {Errno::NONE, Errno::ERANGE}.should contain(ret.ec)
  value
end

RAW_BASE_URL = "https://raw.githubusercontent.com/fastfloat/supplemental_test_files/7cc512a7c60361ebe1baf54991d7905efdc62aa0/data/" # @1.0.0

TEST_SUITES = %w(
  freetype-2-7.txt
  google-double-conversion.txt
  google-wuffs.txt
  ibm-fpgen.txt
  lemire-fast-double-parser.txt
  lemire-fast-float.txt
  more-test-cases.txt
  remyoudompheng-fptest-0.txt
  remyoudompheng-fptest-1.txt
  remyoudompheng-fptest-2.txt
  remyoudompheng-fptest-3.txt
  tencent-rapidjson.txt
  ulfjack-ryu.txt
)

test_suite_cache = {} of String => Array({UInt32, UInt64, String})
puts "Fetching #{TEST_SUITES.size} test suites"
WaitGroup.wait do |wg|
  TEST_SUITES.each do |suite|
    wg.spawn do
      url = RAW_BASE_URL + suite

      cache = HTTP::Client.get(url) do |res|
        res.body_io.each_line.map do |line|
          args = line.split(' ')
          raise "BUG: should have 4 args" unless args.size == 4

          # f16_bits = args[0].to_u16(16)
          f32_bits = args[1].to_u32(16)
          f64_bits = args[2].to_u64(16)
          str = args[3]

          {f32_bits, f64_bits, str}
        end.to_a
      end

      puts "#{cache.size} test cases cached from #{url}"
      test_suite_cache[suite] = cache
    end
  end
end
puts "There are a total of #{test_suite_cache.sum(&.last.size)} test cases"

describe String do
  describe "#to_f" do
    test_suite_cache.each do |suite, cache|
      describe suite do
        each_hardware_rounding_mode do |mode, mode_name|
          it mode_name do
            cache.each do |f32_bits, f64_bits, str|
              fast_float_to_f32(str).unsafe_as(UInt32).should eq(f32_bits)
              fast_float_to_f64(str).unsafe_as(UInt64).should eq(f64_bits)
            end
          end
        end
      end
    end
  end
end
