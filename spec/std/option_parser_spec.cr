require "spec"
require "option_parser"

private def expect_capture_option(args, option, expect_value, expect_args = [] of String,
                                  add_args = ["arg"], block_first = false, &block)
  args += add_args
  flag = nil
  OptionParser.parse(args) do |opts|
    yield opts if block_first
    opts.on(option, "some flag") do |flag_value|
      flag = flag_value
    end
    yield opts unless block_first
  end
  flag.should eq(expect_value)
  args.should eq(expect_args + add_args)
end

private def expect_capture_option(args, option, expect_value, expect_args = [] of String, add_args = ["arg"])
  expect_capture_option(args, option, expect_value, expect_args) { }
end

private def expect_capture_optional_option(args_type, flag_type, value = "123",
                                           expect_value = value, expect_args = [] of String, &block)
  expect_capture_option args_type == :args_separated ? ["--flag", value] : ["--flag=#{value}"],
    flag_type == :flag_separated ? "--flag [FLAG]" : "--flag=[FLAG]", expect_value, expect_args do |opts|
    yield opts
  end
  expect_capture_option args_type == :args_separated ? ["-f", value] : ["-f#{value}"],
    flag_type == :flag_separated ? "-f [FLAG]" : "-f[FLAG]", expect_value, expect_args do |opts|
    yield opts
  end
end

private def expect_capture_optional_option(args_type, flag_type, value = "123",
                                           expect_value = value, expect_args = [] of String)
  expect_capture_optional_option(args_type, flag_type, value, expect_value, expect_args) { }
end

private def expect_doesnt_capture_option(args, option, expect_args = [] of String)
  flag = false
  OptionParser.parse(args) do |opts|
    opts.on(option, "some flag") do
      flag = true
    end
  end
  flag.should be_false
  args.should eq(expect_args)
end

private def expect_missing_option(args, option, flag)
  expect_raises OptionParser::MissingOption, "Missing option: #{flag}" do
    OptionParser.parse(args) do |opts|
      opts.on(option, "some flag") do |flag_value|
      end
    end
  end
end

describe "OptionParser" do
  it "has flag" do
    expect_capture_option ["-f"], "-f", ""
  end

  it "has flag with many letters" do
    expect_capture_option ["-ll"], "-ll", "l"
  end

  it "doesn't have flag" do
    expect_doesnt_capture_option [] of String, "-f"
  end

  it "has flag with double dash" do
    expect_capture_option ["--flag"], "--flag", ""
  end

  it "doesn't have flag with double dash" do
    expect_doesnt_capture_option [] of String, "--flag"
  end

  it "has required option next to flag" do
    expect_capture_option ["-f123"], "-fFLAG", "123"
  end

  it "has required option next to flag but given separated" do
    expect_capture_option ["-f", "123"], "-fFLAG", "123"
  end

  it "raises if missing option next to flag" do
    expect_missing_option ["-f"], "-fFLAG", "-f"
  end

  it "has required option separated from flag" do
    expect_capture_option ["-f", "123"], "-f FLAG", "123"
  end

  it "has required option separated from flag but given together" do
    expect_capture_option ["-f123"], "-f FLAG", "123"
  end

  it "gets short option with value that looks like flag" do
    expect_capture_option ["-f", "-g -h"], "-f FLAG", "-g -h"
  end

  it "raises if missing required option with space" do
    expect_missing_option ["-f"], "-f FLAG", "-f"
  end

  it "has required option separated from long flag" do
    expect_capture_option ["--flag", "123"], "--flag FLAG", "123"
  end

  it "has required option with =" do
    expect_capture_option ["--flag=123"], "--flag FLAG", "123"
  end

  it "has required option with = (2)" do
    expect_capture_option ["--flag=123"], "--flag=FLAG", "123"
  end

  it "has required option with = (3) raises" do
    expect_missing_option ["--flag="], "--flag=FLAG", "--flag"
  end

  it "raises if missing required argument separated from long flag" do
    expect_missing_option ["--flag"], "--flag FLAG", "--flag"
  end

  it "has required option with space" do
    expect_capture_option ["-f", "123"], "-f ", "123"
  end

  it "has required option with long flag space" do
    expect_capture_option ["--flag", "123"], "--flag ", "123"
  end

  it "doesn't raise if required option is not specified" do
    expect_doesnt_capture_option [] of String, "-f "
  end

  it "doesn't raise if optional option is not specified with short flag" do
    expect_doesnt_capture_option [] of String, "-f[FLAG]"
  end

  it "doesn't raise if optional option is not specified with long flag" do
    expect_doesnt_capture_option [] of String, "--flag [FLAG]"
  end

  it "doesn't raise if optional option is not specified with separated short flag" do
    expect_doesnt_capture_option [] of String, "-f [FLAG]"
  end

  it "doesn't raise if required option is not specified with separated short flag" do
    expect_doesnt_capture_option [] of String, "-f FLAG"
  end

  it "parses argument when only referenced in long flag" do
    captured = ""
    parser = OptionParser.parse([] of String) do |opts|
      opts.on("-f", "--flag X", "some flag") { |x| captured = x }
    end
    parser.parse(["-f", "12"])
    captured.should eq "12"
    parser.to_s.should contain "   -f, --flag X"
  end

  it "parses argument when referenced in long and short flag" do
    captured = ""
    parser = OptionParser.parse([] of String) do |opts|
      opts.on("-f X", "--flag X", "some flag") { |x| captured = x }
    end
    parser.parse(["-f", "12"])
    captured.should eq "12"
    parser.to_s.should contain "   -f X, --flag X"
  end

  it "does to_s with banner" do
    parser = OptionParser.parse([] of String) do |opts|
      opts.banner = "Usage: foo"
      opts.on("-f", "--flag", "some flag") do
      end
      opts.on("-g[FLAG]", "some other flag") do
      end
    end
    parser.to_s.should eq <<-USAGE
      Usage: foo
          -f, --flag                       some flag
          -g[FLAG]                         some other flag
      USAGE
  end

  it "does to_s with separators" do
    parser = OptionParser.parse([] of String) do |opts|
      opts.banner = "Usage: foo"
      opts.separator
      opts.separator "Type F flags:"
      opts.on("-f", "--flag", "some flag") do
      end
      opts.separator
      opts.separator "Type G flags:"
      opts.on("-g[FLAG]", "some other flag") do
      end
    end
    parser.to_s.should eq <<-USAGE
      Usage: foo

      Type F flags:
          -f, --flag                       some flag

      Type G flags:
          -g[FLAG]                         some other flag
      USAGE
  end

  it "does to_s with very long flag (#3305)" do
    parser = OptionParser.parse([] of String) do |opts|
      opts.banner = "Usage: foo"
      opts.on("--very_long_option_kills=formatter", "long") do
      end
      opts.on("-f", "--flag", "some flag") do
      end
      opts.on("-g[FLAG]", "some other flag") do
      end
    end
    parser.to_s.should eq <<-USAGE
      Usage: foo
          --very_long_option_kills=formatter
                                           long
          -f, --flag                       some flag
          -g[FLAG]                         some other flag
      USAGE
  end

  it "raises on invalid option" do
    expect_raises OptionParser::InvalidOption, "Invalid option: -j" do
      OptionParser.parse(["-f", "-j"]) do |opts|
        opts.on("-f", "some flag") { }
      end
    end
  end

  it "calls the handler for invalid options" do
    called = false
    OptionParser.parse(["-f", "-j"]) do |opts|
      opts.on("-f", "some flag") { }
      opts.invalid_option do |flag|
        flag.should eq("-j")
        called = true
      end
    end

    called.should be_true
  end

  it "calls the handler for missing options" do
    called = false
    OptionParser.parse(["-f"]) do |opts|
      opts.on("-f FOO", "some flag") { }
      opts.missing_option do |flag|
        flag.should eq("-f")
        called = true
      end
    end

    called.should be_true
  end

  describe "multiple times" do
    it "gets an existence flag multiple times" do
      args = %w(-f -f -f)
      count = 0
      OptionParser.parse(args) do |opts|
        opts.on("-f", "some flag") do
          count += 1
        end
      end
      count.should eq(3)
    end

    it "gets a single flag option multiple times" do
      args = %w(-f 1 -f 2)
      values = [] of String
      OptionParser.parse(args) do |opts|
        opts.on("-f VALUE", "some flag") do |value|
          values << value
        end
      end
      values.should eq(%w(1 2))
    end

    it "gets a double flag option multiple times" do
      args = %w(--f 1 --f 2)
      values = [] of String
      OptionParser.parse(args) do |opts|
        opts.on("--f VALUE", "some flag") do |value|
          values << value
        end
      end
      values.should eq(%w(1 2))
    end
  end

  describe "--" do
    it "ignores everything after -- with bool flag" do
      args = ["-f", "bar", "--", "baz", "qux", "-g"]
      f = false
      g = false
      OptionParser.parse(args) do |opts|
        opts.on("-f", "some flag") do
          f = true
        end
        opts.on("-g", "some flag") do
          g = true
        end
      end
      f.should be_true
      g.should be_false
      args.should eq(["bar", "baz", "qux", "-g"])
    end

    it "ignores everything after -- with single flag)" do
      args = ["-f", "bar", "x", "--", "baz", "qux", "-g", "lala"]
      f = nil
      g = nil
      OptionParser.parse(args) do |opts|
        opts.on("-f FLAG", "some flag") do |v|
          f = v
        end
        opts.on("-g FLAG", "some flag") do |v|
          g = v
        end
      end
      f.should eq("bar")
      g.should be_nil
      args.should eq(["x", "baz", "qux", "-g", "lala"])
    end

    it "ignores everything after -- with double flag" do
      args = ["--f", "bar", "x", "--", "baz", "qux", "--g", "lala"]
      f = nil
      g = nil
      OptionParser.parse(args) do |opts|
        opts.on("--f FLAG", "some flag") do |v|
          f = v
        end
        opts.on("--g FLAG", "some flag") do |v|
          g = v
        end
      end
      f.should eq("bar")
      g.should be_nil
      args.should eq(["x", "baz", "qux", "--g", "lala"])
    end

    it "returns a pair with things coming before and after --" do
      args = %w(--f bar baz -- qux)
      f = nil
      unknown_args = nil
      OptionParser.parse(args) do |opts|
        opts.on("--f FLAG", "some flag") do |v|
          f = v
        end
        opts.unknown_args do |before_dash, after_dash|
          unknown_args = {before_dash, after_dash}
        end
      end
      f.should eq("bar")
      args.should eq(["baz", "qux"])
      unknown_args.should eq({["baz"], ["qux"]})
    end

    it "returns a pair with things coming before and after --, without --" do
      args = %w(--f bar baz)
      f = nil
      unknown_args = nil
      OptionParser.parse(args) do |opts|
        opts.on("--f FLAG", "some flag") do |v|
          f = v
        end
        opts.unknown_args do |before_dash, after_dash|
          unknown_args = {before_dash, after_dash}
        end
      end
      f.should eq("bar")
      args.should eq(["baz"])
      unknown_args.should eq({["baz"], [] of String})
    end

    it "initializes without block and does parse!" do
      old_argv = ARGV.dup
      begin
        ARGV.clear
        ARGV.concat %w(--f hi)
        f = nil
        OptionParser.new do |opts|
          opts.on("--f FLAG", "some flag") do |v|
            f = v
          end
        end.parse!
        f.should eq("hi")
      ensure
        ARGV.clear
        ARGV.concat old_argv
      end
    end

    it "gets `-` as argument" do
      args = %w(-)
      OptionParser.parse(args) do |opts|
      end
      args.should eq(%w(-))
    end
  end

  describe "forward-match" do
    it "distinguishes between '--lamb VALUE' and '--lambda VALUE'" do
      args = %w(--lamb value1 --lambda value2)
      value1 = nil
      value2 = nil
      OptionParser.parse(args) do |opts|
        opts.on("--lamb VALUE", "") { |v| value1 = v }
        opts.on("--lambda VALUE", "") { |v| value2 = v }
      end
      value1.should eq("value1")
      value2.should eq("value2")
    end

    it "distinguishes between '--lamb=VALUE' and '--lambda=VALUE'" do
      args = %w(--lamb=value1 --lambda=value2)
      value1 = nil
      value2 = nil
      OptionParser.parse(args) do |opts|
        opts.on("--lamb=VALUE", "") { |v| value1 = v }
        opts.on("--lambda=VALUE", "") { |v| value2 = v }
      end
      value1.should eq("value1")
      value2.should eq("value2")
    end
  end

  describe "optional option" do
    it "gets merged value if specified with separated flag" do
      expect_capture_optional_option :args_merged, :flag_separated
    end

    it "gets merged value if specified with merged flag" do
      expect_capture_optional_option :args_merged, :flag_merged
    end

    it "gets separated value if specified with separated flag" do
      expect_capture_optional_option :args_separated, :flag_separated
    end

    it "doesn't get separated value if specified with merged flag" do
      expect_capture_optional_option :args_separated, :flag_merged, value: "123",
        expect_value: "", expect_args: ["123"]
    end

    it "gets merged value that looks like flag if specified with separated flag" do
      expect_capture_optional_option :args_merged, :flag_separated, value: "-g -h"
    end

    it "doesn't get separated value that looks like flag if specified with separated flag" do
      captured_g = nil
      expect_capture_optional_option :args_separated, :flag_separated, value: "-g -h", expect_value: "" do |opts|
        opts.on("-g [FLAG]", "another flag") { |flag_value| captured_g = flag_value }
      end
      captured_g.should eq(" -h")
    end
  end

  it "doesn't get value shifted in position because of removing another flag" do
    2.times do |i|
      captured_g = nil
      expect_capture_option ["-f", "-g", "123"], "-f [FLAG]", block_first: i == 0,
        expect_value: "", expect_args: ["123"] do |opts|
        opts.on("-g", "another flag") { |flag_value| captured_g = flag_value }
      end
      captured_g.should eq("")
    end
  end

  it "should take short-flag's missing information about option from long flag" do
    args = ["-f", "12", "-g", "13", "-h", "14"]
    captured_f = captured_g = captured_z = nil
    parser = OptionParser.parse(args) do |opts|
      opts.on("-f", "--flag X", "some flag") { |flag_value| captured_f = flag_value }
      opts.on("-g", "--gflag=Y", "another flag") { |flag_value| captured_g = flag_value }
      opts.on("-h", "--hopt=[Z]", "optional flag") { |flag_value| captured_z = flag_value }
    end
    captured_f.should eq "12"
    captured_g.should eq "13"
    captured_z.should eq ""
    args.should eq ["14"]
    parser.to_s.should contain "   -f, --flag X"
  end

  it "raises if flag doesn't start with dash (#4001)" do
    OptionParser.parse([] of String) do |opts|
      expect_raises ArgumentError, %(Argument 'flag' ("foo") must start with a dash) do
        opts.on("foo", "") { }
      end

      expect_raises ArgumentError, %(Argument 'short_flag' ("foo") must start with a dash) do
        opts.on("foo", "bar", "baz") { }
      end

      expect_raises ArgumentError, %(Argument 'long_flag' ("bar") must start with a dash) do
        opts.on("-foo", "bar", "baz") { }
      end

      opts.on("", "-bar", "baz") { }
    end
  end
end
