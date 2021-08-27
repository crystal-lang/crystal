require "spec"
require "../support/string"

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

describe Number do
  describe "#format" do
    it { assert_prints 1.format, "1" }
    it { assert_prints 12.format, "12" }
    it { assert_prints 123.format, "123" }
    it { assert_prints 1234.format, "1,234" }

    it { assert_prints 123.45.format, "123.45" }
    it { assert_prints 123.45.format(separator: ','), "123,45" }
    it { assert_prints 123.45.format(decimal_places: 3), "123.450" }
    it { assert_prints 123.45.format(decimal_places: 3, only_significant: true), "123.45" }
    it { assert_prints 123.4567.format(decimal_places: 3), "123.457" }

    it { assert_prints 123_456.format, "123,456" }
    it { assert_prints 123_456.format(delimiter: '.'), "123.456" }

    it { assert_prints 123_456.789.format, "123,456.789" }
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

    it { assert_prints 1536.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.5KB" }
    it { assert_prints 524288.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "512KB" }
    it { assert_prints 1048576.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0MB" }
    it { assert_prints 1073741824.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0GB" }
    it { assert_prints 1099511627776.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0TB" }
    it { assert_prints 1125899906842624.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0PB" }
    it { assert_prints 1152921504606846976.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC), "1.0EB" }

    it { assert_prints 1024.humanize_bytes(format: Int::BinaryPrefixFormat::IEC), "1.0kiB" }
    it { assert_prints 1073741824.humanize_bytes(format: Int::BinaryPrefixFormat::IEC), "1.0GiB" }
  end
end
