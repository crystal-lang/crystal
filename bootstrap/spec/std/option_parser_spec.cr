#!/usr/bin/env bin/crystal -run
require "spec"
require "option_parser"

describe "OptionParser" do
  def expect_missing_argument(args, option, flag)
    begin
      OptionParser.parse(args) do |opts|
        opts.on(option, "some flag") do |value|
        end
      end
      fail "Expected to raise OptionParser::MissingArgument"
    rescue ex : OptionParser::MissingArgument
      ex.message.should eq("Missing argument: #{flag}")
    end
  end

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

  def expect_doesnt_raise_for_optional_argument(option)
    flag = nil
    OptionParser.parse([] of String) do |opts|
      opts.on(option, "some flag") do |flag_value|
        flag = flag_value
      end
    end
    flag.should be_nil
  end

  it "has flag" do
    expect_capture_option ["-f"], "-f", true
  end

  it "has flag with many letters" do
    expect_capture_option ["-ll"], "-ll", true
  end

  it "doesn't have flag" do
    expect_doesnt_capture_option ([] of String), "-f"
  end

  it "has flag with double dash" do
    expect_capture_option ["--flag"], "--flag", true
  end

  it "doesn't have flag with double dash" do
    expect_doesnt_capture_option ([] of String), "--flag"
  end

  it "has required option next to flag" do
    expect_capture_option ["-f123"], "-fFLAG", "123"
  end

  it "raises if missing required option" do
    expect_missing_argument ([] of String), "-fFLAG", "-f"
  end

  it "has required option separated from flag" do
    expect_capture_option ["-f", "123"], "-f FLAG", "123"
  end

  it "raises if missing required argument" do
    expect_missing_argument ["-f"], "-f FLAG", "-f"
  end

  it "has required option separated from long flag" do
    expect_capture_option ["--flag", "123"], "--flag FLAG", "123"
  end

  it "raises if missing required argument separated from long flag" do
    expect_missing_argument ["--flag"], "--flag FLAG", "--flag"
  end

  it "has optional option with space" do
    expect_capture_option ["-f", "123"], "-f ", "123"
  end

  it "doesn't raise if optional option is not specified" do
    expect_doesnt_raise_for_optional_argument "-f "
  end

  it "doesn't raise if optional option is not specified with short flag" do
    expect_doesnt_raise_for_optional_argument "-f[FLAG]"
  end

  it "doesn't raise if optional option is not specified with long flag" do
    expect_doesnt_raise_for_optional_argument "--flag [FLAG]"
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
end
