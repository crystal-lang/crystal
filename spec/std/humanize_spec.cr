require "spec"

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
    it do
      1.format.should eq "1"
      12.format.should eq "12"
      123.format.should eq "123"
      1234.format.should eq "1,234"

      123.45.format.should eq "123.45"
      123.45.format(separator: ',').should eq "123,45"
      123.45.format(decimal_places: 3).should eq "123.450"
      123.45.format(decimal_places: 3, only_significant: true).should eq "123.45"
      123.4567.format(decimal_places: 3).should eq "123.457"

      123_456.format.should eq "123,456"
      123_456.format(delimiter: '.').should eq "123.456"

      123_456.789.format.should eq "123,456.789"
    end
  end

  describe "#humanize" do
    it { 0.humanize.should eq "0.0" }
    it { 1.humanize.should eq "1.0" }
    it { -1.humanize.should eq "-1.0" }
    it { 123.humanize.should eq "123" }
    it { 123.humanize(2).should eq "120" }
    it { 1234.humanize.should eq "1.23k" }
    it { 12_345.humanize.should eq "12.3k" }
    it { 12_345.humanize(2).should eq "12k" }
    it { 1_234_567.humanize.should eq "1.23M" }
    it { 1_234_567.humanize(5).should eq "1.2346M" }
    it { 12_345_678.humanize(5).should eq "12.346M" }
    it { 0.012_345.humanize.should eq "12.3m" }
    it { 0.001_234_5.humanize.should eq "1.23m" }
    it { 0.000_000_012_345.humanize.should eq "12.3n" }
    it { 0.000_000_001.humanize.should eq "1.0n" }
    it { 0.000_000_001_235.humanize.should eq "1.24n" }
    it { 0.123_456_78.humanize.should eq "123m" }
    it { 0.123_456_78.humanize(5).should eq "123.46m" }

    it { 1_234.567_890_123.humanize(precision: 2, significant: false).should eq("1.23k") }
    it { 123.456_789_012_3.humanize(precision: 2, significant: false).should eq("123.46") }
    it { 12.345_678_901_23.humanize(precision: 2, significant: false).should eq("12.35") }
    it { 1.234_567_890_123.humanize(precision: 2, significant: false).should eq("1.23") }

    it { 0.123_456_789_012.humanize(precision: 2, significant: false).should eq("123.46m") }
    it { 0.012_345_678_901.humanize(precision: 2, significant: false).should eq("12.35m") }
    it { 0.001_234_567_890.humanize(precision: 2, significant: false).should eq("1.23m") }

    it { 0.000_123_456_789.humanize(precision: 2, significant: false).should eq("123.46µ") }
    it { 0.000_012_345_678.humanize(precision: 2, significant: false).should eq("12.35µ") }
    it { 0.000_001_234_567.humanize(precision: 2, significant: false).should eq("1.23µ") }

    it { 0.000_000_123_456.humanize(precision: 2, significant: false).should eq("123.46n") }
    it { 0.000_000_012_345.humanize(precision: 2, significant: false).should eq("12.35n") }
    it { 0.000_000_001_234.humanize(precision: 2, significant: false).should eq("1.23n") }
    it { 0.000_000_000_123.humanize(precision: 2, significant: false).should eq("123.00p") }

    describe "using custom prefixes" do
      it { 1_420_000_000.humanize(prefixes: LENGTH_UNITS).should eq "1,420,000 km" }
      it { 1_420.humanize(prefixes: LENGTH_UNITS).should eq "1.42 km" }
      it { 1.humanize(prefixes: LENGTH_UNITS).should eq "1.0 m" }
      it { 0.1.humanize(prefixes: LENGTH_UNITS).should eq "10.0 cm" }
      it { 0.01.humanize(prefixes: LENGTH_UNITS).should eq "1.0 cm" }
      it { 0.001.humanize(prefixes: LENGTH_UNITS).should eq "1.0 mm" }
      it { 0.000_01.humanize(prefixes: LENGTH_UNITS).should eq "10.0 µm" }
      it { 0.000_000_001.humanize(prefixes: LENGTH_UNITS).should eq "1.0 nm" }
    end
  end
end

describe Int do
  describe "#humanize_bytes" do
    # default IEC
    it { 1024.humanize_bytes.should eq "1.0kiB" }

    it { 0.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "0B" }
    it { 1.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "1B" }
    it { 1000.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "1000B" }
    it { 1014.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "0.99KB" }
    it { 1015.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "1.0KB" }
    it { 1024.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "1.0KB" }
    it { 1025.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "1.01KB" }
    it { 2048.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq "2.0KB" }

    it { 1536.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("1.5KB") }
    it { 524288.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("512KB") }
    it { 1048576.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("1.0MB") }
    it { 1073741824.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("1.0GB") }
    it { 1099511627776.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("1.0TB") }
    it { 1125899906842624.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("1.0PB") }
    it { 1152921504606846976.humanize_bytes(format: Int::BinaryPrefixFormat::JEDEC).should eq("1.0EB") }

    it { 1024.humanize_bytes(format: Int::BinaryPrefixFormat::IEC).should eq "1.0kiB" }
    it { 1073741824.humanize_bytes(format: Int::BinaryPrefixFormat::IEC).should eq "1.0GiB" }
  end
end
