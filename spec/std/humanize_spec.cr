require "spec"
require "spec/helpers/string"
require "big"

private LENGTH_UNITS = ->(magnitude : Int32, number : Float64) do
  case magnitude
  when -2, -1 then {-2, " cm"}
  when .>=(4)
    {3, " km"}
  else
    magnitude = Number.prefix_index(magnitude)
    {magnitude, " #{Number.si_prefix(magnitude)}m"}
  end
end

private CUSTOM_PREFIXES = [['a'], ['b', 'c', 'd']]

describe Number do
  describe "#format" do
    it { assert_prints 1.format, "1" }
    it { assert_prints 12.format, "12" }
    it { assert_prints 123.format, "123" }
    it { assert_prints 1234.format, "1,234" }

    it { assert_prints 1.format(decimal_places: 1), "1.0" }
    it { assert_prints 1.format(decimal_places: 1, only_significant: true), "1.0" }

    it { assert_prints 0.format(decimal_places: 1), "0.0" }
    it { assert_prints 0.format(decimal_places: 1, only_significant: true), "0.0" }

    it { assert_prints 0.0.format(decimal_places: 1), "0.0" }
    it { assert_prints 0.0.format(decimal_places: 1, only_significant: true), "0.0" }

    it { assert_prints 0.01.format(decimal_places: 1), "0.0" }

    it { assert_prints 123.45.format, "123.45" }
    it { assert_prints 123.45.format(separator: ','), "123,45" }
    it { assert_prints 123.45.format(decimal_places: 3), "123.450" }
    it { assert_prints 123.45.format(decimal_places: 3, only_significant: true), "123.45" }
    it { assert_prints 123.4567.format(decimal_places: 3), "123.457" }

    it { assert_prints 123_456.format, "123,456" }
    it { assert_prints 123_456.format(delimiter: '.'), "123.456" }

    it { assert_prints 123_456.789.format, "123,456.789" }

    it { assert_prints 1e15.format(decimal_places: 7), "1,000,000,000,000,000.0000000" }
    it { assert_prints 1e15.to_i64.format(decimal_places: 7), "1,000,000,000,000,000.0000000" }
    it { assert_prints 1e-5.format(decimal_places: 7), "0.0000100" }
    it { assert_prints 1e-4.format(decimal_places: 7), "0.0001000" }

    it { assert_prints -1.format, "-1" }
    it { assert_prints -12.format, "-12" }
    it { assert_prints -123.format, "-123" }
    it { assert_prints -1234.format, "-1,234" }

    it { assert_prints -1.format(decimal_places: 1), "-1.0" }
    it { assert_prints -1.format(decimal_places: 1, only_significant: true), "-1.0" }

    it { assert_prints -0.0.format(decimal_places: 1), "-0.0" }
    it { assert_prints -0.0.format(decimal_places: 1, only_significant: true), "-0.0" }

    it { assert_prints -0.01.format(decimal_places: 1), "-0.0" }

    it { assert_prints -123.45.format, "-123.45" }
    it { assert_prints -123.45.format(separator: ','), "-123,45" }
    it { assert_prints -123.45.format(decimal_places: 3), "-123.450" }
    it { assert_prints -123.45.format(decimal_places: 3, only_significant: true), "-123.45" }
    it { assert_prints -123.4567.format(decimal_places: 3), "-123.457" }

    it { assert_prints -123_456.format, "-123,456" }
    it { assert_prints -123_456.format(delimiter: '.'), "-123.456" }

    it { assert_prints -123_456.789.format, "-123,456.789" }

    it { assert_prints -1e15.format(decimal_places: 7), "-1,000,000,000,000,000.0000000" }
    it { assert_prints -1e15.to_i64.format(decimal_places: 7), "-1,000,000,000,000,000.0000000" }
    it { assert_prints -1e-5.format(decimal_places: 7), "-0.0000100" }
    it { assert_prints -1e-4.format(decimal_places: 7), "-0.0001000" }

    it { assert_prints Float64::MAX.format, "179,769,313,486,231,570,814,527,423,731,704,356,798,070,567,525,844,996,598,917,476,803,157,260,780,028,538,760,589,558,632,766,878,171,540,458,953,514,382,464,234,321,326,889,464,182,768,467,546,703,537,516,986,049,910,576,551,282,076,245,490,090,389,328,944,075,868,508,455,133,942,304,583,236,903,222,948,165,808,559,332,123,348,274,797,826,204,144,723,168,738,177,180,919,299,881,250,404,026,184,124,858,368.0" }
    it { assert_prints Float64::MIN.format, "-179,769,313,486,231,570,814,527,423,731,704,356,798,070,567,525,844,996,598,917,476,803,157,260,780,028,538,760,589,558,632,766,878,171,540,458,953,514,382,464,234,321,326,889,464,182,768,467,546,703,537,516,986,049,910,576,551,282,076,245,490,090,389,328,944,075,868,508,455,133,942,304,583,236,903,222,948,165,808,559,332,123,348,274,797,826,204,144,723,168,738,177,180,919,299,881,250,404,026,184,124,858,368.0" }
    it { assert_prints Float64::MAX.format(decimal_places: 0), "179,769,313,486,231,570,814,527,423,731,704,356,798,070,567,525,844,996,598,917,476,803,157,260,780,028,538,760,589,558,632,766,878,171,540,458,953,514,382,464,234,321,326,889,464,182,768,467,546,703,537,516,986,049,910,576,551,282,076,245,490,090,389,328,944,075,868,508,455,133,942,304,583,236,903,222,948,165,808,559,332,123,348,274,797,826,204,144,723,168,738,177,180,919,299,881,250,404,026,184,124,858,368" }
    it { assert_prints Float64::MIN.format(decimal_places: 0), "-179,769,313,486,231,570,814,527,423,731,704,356,798,070,567,525,844,996,598,917,476,803,157,260,780,028,538,760,589,558,632,766,878,171,540,458,953,514,382,464,234,321,326,889,464,182,768,467,546,703,537,516,986,049,910,576,551,282,076,245,490,090,389,328,944,075,868,508,455,133,942,304,583,236,903,222,948,165,808,559,332,123,348,274,797,826,204,144,723,168,738,177,180,919,299,881,250,404,026,184,124,858,368" }
    it { assert_prints Float64::MIN_POSITIVE.format, "0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022250738585072014" }
    it { assert_prints (-Float64::MIN_POSITIVE).format, "-0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022250738585072014" }

    it { assert_prints Float32::INFINITY.format, "Infinity" }
    it { assert_prints (-Float32::INFINITY).format, "-Infinity" }
    it { assert_prints Float32::NAN.format, "NaN" }

    it { assert_prints Float64::INFINITY.format, "Infinity" }
    it { assert_prints (-Float64::INFINITY).format, "-Infinity" }
    it { assert_prints Float64::NAN.format, "NaN" }

    it { assert_prints "12345.67890123456789012345".to_big_d.format, "12,345.67890123456789012345" }

    it "extracts integer part correctly (#12997)" do
      assert_prints 1.9999998.format, "1.9999998"
      assert_prints 1111111.999999998.format, "1,111,111.999999998"
    end

    it "does not perform double rounding when decimal places are given" do
      assert_prints 1.2345.format(decimal_places: 24), "1.234499999999999930722083"
      assert_prints 1.2345.format(decimal_places: 65), "1.23449999999999993072208326339023187756538391113281250000000000000"
      assert_prints 1.2345.format(decimal_places: 71), "1.23449999999999993072208326339023187756538391113281250000000000000000000"
      assert_prints 1.2345.format(decimal_places: 83), "1.23449999999999993072208326339023187756538391113281250000000000000000000000000000000"
      assert_prints 1.2345.format(decimal_places: 99), "1.234499999999999930722083263390231877565383911132812500000000000000000000000000000000000000000000000"
    end
  end

  describe "#humanize" do
    it { assert_prints 0.humanize, "0.0" }
    it { assert_prints 1.humanize, "1.0" }
    it { assert_prints (-1).humanize, "-1.0" }
    it { assert_prints 99.humanize, "99.0" }
    it { assert_prints 100.humanize, "100" }
    it { assert_prints 101.humanize, "101" }
    it { assert_prints 123.humanize, "123" }
    it { assert_prints 123.humanize(2), "120" }
    it { assert_prints 999.humanize, "999" }
    it { assert_prints 1000.humanize, "1.0k" }
    it { assert_prints 1001.humanize, "1.0k" }
    it { assert_prints 1234.humanize, "1.23k" }
    it { assert_prints 12_345.humanize, "12.3k" }
    it { assert_prints 12_345.humanize(2), "12k" }
    it { assert_prints 1_234_567.humanize, "1.23M" }
    it { assert_prints 1_234_567.humanize(5), "1.2346M" }
    it { assert_prints 12_345_678.humanize(5), "12.346M" }
    it { assert_prints 0.012_345.humanize, "12.3m" }
    it { assert_prints 0.001_234_5.humanize, "1.23m" }
    it { assert_prints 0.000_000_012_345.humanize, "12.3n" }
    it { assert_prints 0.000_000_001.humanize, "1.0n" }
    it { assert_prints 0.000_000_001_235.humanize, "1.24n" }
    it { assert_prints 0.123_456_78.humanize, "123m" }
    it { assert_prints 0.123_456_78.humanize(5), "123.46m" }

    it { assert_prints 1.0e-35.humanize, "0.00001q" }
    it { assert_prints 1.0e-34.humanize, "0.0001q" }
    it { assert_prints 1.0e-33.humanize, "0.001q" }
    it { assert_prints 1.0e-32.humanize, "0.01q" }
    it { assert_prints 1.0e-31.humanize, "0.1q" }
    it { assert_prints 1.0e-30.humanize, "1.0q" }
    it { assert_prints 1.0e-29.humanize, "10.0q" }
    it { assert_prints 1.0e-28.humanize, "100q" }
    it { assert_prints 1.0e-27.humanize, "1.0r" }
    it { assert_prints 1.0e-26.humanize, "10.0r" }
    it { assert_prints 1.0e-25.humanize, "100r" }
    it { assert_prints 1.0e-24.humanize, "1.0y" }
    it { assert_prints 1.0e-23.humanize, "10.0y" }
    it { assert_prints 1.0e-22.humanize, "100y" }
    it { assert_prints 1.0e-21.humanize, "1.0z" }
    it { assert_prints 1.0e-20.humanize, "10.0z" }
    it { assert_prints 1.0e-19.humanize, "100z" }
    it { assert_prints 1.0e-18.humanize, "1.0a" }
    it { assert_prints 1.0e-17.humanize, "10.0a" }
    it { assert_prints 1.0e-16.humanize, "100a" }
    it { assert_prints 1.0e-15.humanize, "1.0f" }
    it { assert_prints 1.0e-14.humanize, "10.0f" }
    it { assert_prints 1.0e-13.humanize, "100f" }
    it { assert_prints 1.0e-12.humanize, "1.0p" }
    it { assert_prints 1.0e-11.humanize, "10.0p" }
    it { assert_prints 1.0e-10.humanize, "100p" }
    it { assert_prints 1.0e-9.humanize, "1.0n" }
    it { assert_prints 1.0e-8.humanize, "10.0n" }
    it { assert_prints 1.0e-7.humanize, "100n" }
    it { assert_prints 1.0e-6.humanize, "1.0µ" }
    it { assert_prints 1.0e-5.humanize, "10.0µ" }
    it { assert_prints 1.0e-4.humanize, "100µ" }
    it { assert_prints 1.0e-3.humanize, "1.0m" }
    it { assert_prints 1.0e-2.humanize, "10.0m" }
    it { assert_prints 1.0e-1.humanize, "100m" }
    it { assert_prints 1.0e+0.humanize, "1.0" }
    it { assert_prints 1.0e+1.humanize, "10.0" }
    it { assert_prints 1.0e+2.humanize, "100" }
    it { assert_prints 1.0e+3.humanize, "1.0k" }
    it { assert_prints 1.0e+4.humanize, "10.0k" }
    it { assert_prints 1.0e+5.humanize, "100k" }
    it { assert_prints 1.0e+6.humanize, "1.0M" }
    it { assert_prints 1.0e+7.humanize, "10.0M" }
    it { assert_prints 1.0e+8.humanize, "100M" }
    it { assert_prints 1.0e+9.humanize, "1.0G" }
    it { assert_prints 1.0e+10.humanize, "10.0G" }
    it { assert_prints 1.0e+11.humanize, "100G" }
    it { assert_prints 1.0e+12.humanize, "1.0T" }
    it { assert_prints 1.0e+13.humanize, "10.0T" }
    it { assert_prints 1.0e+14.humanize, "100T" }
    it { assert_prints 1.0e+15.humanize, "1.0P" }
    it { assert_prints 1.0e+16.humanize, "10.0P" }
    it { assert_prints 1.0e+17.humanize, "100P" }
    it { assert_prints 1.0e+18.humanize, "1.0E" }
    it { assert_prints 1.0e+19.humanize, "10.0E" }
    it { assert_prints 1.0e+20.humanize, "100E" }
    it { assert_prints 1.0e+21.humanize, "1.0Z" }
    it { assert_prints 1.0e+22.humanize, "10.0Z" }
    it { assert_prints 1.0e+23.humanize, "100Z" }
    it { assert_prints 1.0e+24.humanize, "1.0Y" }
    it { assert_prints 1.0e+25.humanize, "10.0Y" }
    it { assert_prints 1.0e+26.humanize, "100Y" }
    it { assert_prints 1.0e+27.humanize, "1.0R" }
    it { assert_prints 1.0e+28.humanize, "10.0R" }
    it { assert_prints 1.0e+29.humanize, "100R" }
    it { assert_prints 1.0e+30.humanize, "1.0Q" }
    it { assert_prints 1.0e+31.humanize, "10.0Q" }
    it { assert_prints 1.0e+32.humanize, "100Q" }
    it { assert_prints 1.0e+33.humanize, "1,000Q" }
    it { assert_prints 1.0e+34.humanize, "10,000Q" }
    it { assert_prints 1.0e+35.humanize, "100,000Q" }

    it { assert_prints 0.humanize(unit_separator: '_'), "0.0" }
    it { assert_prints 0.123_456_78.humanize(5, unit_separator: '\u00A0'), "123.46\u00A0m" }
    it { assert_prints 1.0e-14.humanize(unit_separator: ' '), "10.0 f" }
    it { assert_prints 0.000_001.humanize(unit_separator: '\u2009'), "1.0\u2009µ" }
    it { assert_prints 1_000_000_000_000.humanize(unit_separator: "__"), "1.0__T" }
    it { assert_prints 0.000_000_001.humanize(unit_separator: "."), "1.0.n" }
    it { assert_prints 1.0e+9.humanize(unit_separator: "\t"), "1.0\tG" }
    it { assert_prints 123_456_789_012.humanize(unit_separator: 0), "1230G" }
    it { assert_prints 123_456_789_012.humanize(unit_separator: nil), "123G" }

    it { assert_prints Float32::INFINITY.humanize, "Infinity" }
    it { assert_prints (-Float32::INFINITY).humanize, "-Infinity" }
    it { assert_prints Float32::NAN.humanize, "NaN" }

    it { assert_prints Float64::INFINITY.humanize, "Infinity" }
    it { assert_prints (-Float64::INFINITY).humanize, "-Infinity" }
    it { assert_prints Float64::NAN.humanize, "NaN" }

    it { assert_prints 1_234.567_890_123.humanize(precision: 2, significant: false), "1.23k" }
    it { assert_prints 123.456_789_012_3.humanize(precision: 2, significant: false), "123.46" }
    it { assert_prints 12.345_678_901_23.humanize(precision: 2, significant: false), "12.35" }
    it { assert_prints 1.234_567_890_123.humanize(precision: 2, significant: false), "1.23" }

    it { assert_prints 0.123_456_789_012.humanize(precision: 2, significant: false), "123.46m" }
    it { assert_prints 0.012_345_678_901.humanize(precision: 2, significant: false), "12.35m" }
    it { assert_prints 0.001_234_567_890.humanize(precision: 2, significant: false), "1.23m" }

    it { assert_prints 0.000_123_456_789.humanize(precision: 2, significant: false), "123.46µ" }
    it { assert_prints 0.000_012_345_678.humanize(precision: 2, significant: false), "12.35µ" }
    it { assert_prints 0.000_001_234_567.humanize(precision: 2, significant: false), "1.23µ" }

    it { assert_prints 0.000_000_123_456.humanize(precision: 2, significant: false), "123.46n" }
    it { assert_prints 0.000_000_012_345.humanize(precision: 2, significant: false), "12.34n" }
    it { assert_prints 0.000_000_001_234.humanize(precision: 2, significant: false), "1.23n" }
    it { assert_prints 0.000_000_000_123.humanize(precision: 2, significant: false), "123.00p" }

    describe "using custom prefixes" do
      it { assert_prints 1_420_000_000.humanize(prefixes: LENGTH_UNITS), "1,420,000 km" }
      it { assert_prints 1_420.humanize(prefixes: LENGTH_UNITS), "1.42 km" }
      it { assert_prints 1.humanize(prefixes: LENGTH_UNITS), "1.0 m" }
      it { assert_prints 0.1.humanize(prefixes: LENGTH_UNITS), "10.0 cm" }
      it { assert_prints 0.01.humanize(prefixes: LENGTH_UNITS), "1.0 cm" }
      it { assert_prints 0.001.humanize(prefixes: LENGTH_UNITS), "1.0 mm" }
      it { assert_prints 0.000_01.humanize(prefixes: LENGTH_UNITS), "10.0 µm" }
      it { assert_prints 0.000_000_001.humanize(prefixes: LENGTH_UNITS), "1.0 nm" }

      it { assert_prints 1.0e-7.humanize(prefixes: CUSTOM_PREFIXES), "0.0001a" }
      it { assert_prints 1.0e-6.humanize(prefixes: CUSTOM_PREFIXES), "0.001a" }
      it { assert_prints 1.0e-5.humanize(prefixes: CUSTOM_PREFIXES), "0.01a" }
      it { assert_prints 1.0e-4.humanize(prefixes: CUSTOM_PREFIXES), "0.1a" }
      it { assert_prints 1.0e-3.humanize(prefixes: CUSTOM_PREFIXES), "1.0a" }
      it { assert_prints 1.0e-2.humanize(prefixes: CUSTOM_PREFIXES), "10.0a" }
      it { assert_prints 1.0e-1.humanize(prefixes: CUSTOM_PREFIXES), "100a" }
      it { assert_prints 1.0e+0.humanize(prefixes: CUSTOM_PREFIXES), "1.0b" }
      it { assert_prints 1.0e+1.humanize(prefixes: CUSTOM_PREFIXES), "10.0b" }
      it { assert_prints 1.0e+2.humanize(prefixes: CUSTOM_PREFIXES), "100b" }
      it { assert_prints 1.0e+3.humanize(prefixes: CUSTOM_PREFIXES), "1.0c" }
      it { assert_prints 1.0e+4.humanize(prefixes: CUSTOM_PREFIXES), "10.0c" }
      it { assert_prints 1.0e+5.humanize(prefixes: CUSTOM_PREFIXES), "100c" }
      it { assert_prints 1.0e+6.humanize(prefixes: CUSTOM_PREFIXES), "1.0d" }
      it { assert_prints 1.0e+7.humanize(prefixes: CUSTOM_PREFIXES), "10.0d" }
      it { assert_prints 1.0e+8.humanize(prefixes: CUSTOM_PREFIXES), "100d" }
      it { assert_prints 1.0e+9.humanize(prefixes: CUSTOM_PREFIXES), "1,000d" }
      it { assert_prints 1.0e+10.humanize(prefixes: CUSTOM_PREFIXES), "10,000d" }
      it { assert_prints 1.0e+10.humanize(prefixes: CUSTOM_PREFIXES, unit_separator: '\u00A0'), "10,000\u00A0d" }
    end
  end
end

describe Int do
  describe "#humanize_bytes" do
    # default IEC
    it { assert_prints 1024.humanize_bytes, "1.0kiB" }

    it { assert_prints 0.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "0B" }
    it { assert_prints 1.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1B" }
    it { assert_prints 999.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "999B" }
    it { assert_prints 1000.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "0.98KB" }
    it { assert_prints 1001.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "0.98KB" }
    it { assert_prints 1014.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "0.99KB" }
    it { assert_prints 1015.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0KB" }
    it { assert_prints 1024.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0KB" }
    it { assert_prints 1025.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0KB" }
    it { assert_prints 1026.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.01KB" }
    it { assert_prints 2048.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "2.0KB" }
    it { assert_prints 2048.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC, unit_separator: '\u202F'), "2.0\u202FKB" }

    it { assert_prints 1536.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.5KB" }
    it { assert_prints 524288.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "512KB" }
    it { assert_prints 1048576.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0MB" }
    it { assert_prints 1073741824.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0GB" }
    it { assert_prints 1099511627776.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0TB" }
    it { assert_prints 1125899906842624.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0PB" }
    it { assert_prints 1152921504606846976.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0EB" }
    it { assert_prints 1152921504606846976.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC, unit_separator: '\u2009'), "1.0\u2009EB" }

    it { assert_prints 1024.humanize_bytes(format: Int::BinaryPrefixFormat::IEC), "1.0kiB" }
    it { assert_prints 1073741824.humanize_bytes(format: Int::BinaryPrefixFormat::IEC), "1.0GiB" }
  end
end
