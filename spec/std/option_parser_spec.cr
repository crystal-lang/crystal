require "spec"
require "option_parser"

def expect_capture_option(args, option, value)
  flag = nil
  OptionParser.parse(args) do |opts|
    opts.on(option, "some flag") do |flag_value|
      flag = flag_value
    end
  end
  flag.should eq(value)
  args.length.should eq(0)
end

def expect_doesnt_capture_option(args, option)
  flag = false
  OptionParser.parse(args) do |opts|
    opts.on(option, "some flag") do
      flag = true
    end
  end
  flag.should be_false
end

def expect_missing_option(option)
  expect_raises OptionParser::MissingOption do
    OptionParser.parse([] of String) do |opts|
      opts.on(option, "some flag") do |flag_value|
      end
    end
  end
end

def expect_missing_option(args, option, flag)
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

  it "doesn't raise if required option is not specified with separated short flag 2" do
    expect_doesnt_capture_option [] of String, "-f FLAG"
  end

  it "does to_s with banner" do
    parser = OptionParser.parse([] of String) do |opts|
      opts.banner = "Usage: foo"
      opts.on("-f", "--flag", "some flag") do
      end
      opts.on("-g[FLAG]", "some other flag") do
      end
    end
    parser.to_s.should eq([
      "Usage: foo",
      "    -f, --flag                       some flag"
      "    -g[FLAG]                         some other flag"
    ].join "\n")
  end

  it "raises on invalid option" do
    expect_raises OptionParser::InvalidOption, "Invalid option: -j" do
      OptionParser.parse(["-f", "-j"]) do |opts|
        opts.on("-f", "some flag") { }
      end
    end
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
  end
end
