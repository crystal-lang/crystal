require "../../spec_helper"

private def assert_expand_regex_const(from : String, to, *, flags = nil, file = __FILE__, line = __LINE__)
  from_nodes = Parser.parse(from)
  assert_expand(from_nodes, flags: flags, file: file, line: line) do |to_nodes, program|
    const = program.types[to_nodes.to_s].should be_a(Crystal::Const), file: file, line: line
    const.value.to_s.should eq(to.strip), file: file, line: line
  end
end

describe "Normalize: regex literal" do
  describe "StringLiteral" do
    it "expands to const" do
      assert_expand Parser.parse(%q(/foo/)) do |to_nodes, program|
        to_nodes.to_s.should eq "$Regex:0"
      end
    end

    it "simple" do
      assert_expand_regex_const %q(/foo/), <<-'CRYSTAL'
      ::Regex.new("foo", ::Regex::Options.new(0))
      CRYSTAL
    end
  end

  describe "StringInterpolation" do
    it "simple" do
      assert_expand %q(/#{"foo".to_s}/), <<-'CRYSTAL'
        ::Regex.new("#{"foo".to_s}", ::Regex::Options.new(0))
        CRYSTAL
    end
  end

  describe "options" do
    it "empty" do
      assert_expand_regex_const %q(//), <<-'CRYSTAL'
      ::Regex.new("", ::Regex::Options.new(0))
      CRYSTAL
    end
    it "i" do
      assert_expand_regex_const %q(//i), <<-'CRYSTAL'
      ::Regex.new("", ::Regex::Options.new(1))
      CRYSTAL
    end
    it "x" do
      assert_expand_regex_const %q(//x), <<-'CRYSTAL'
      ::Regex.new("", ::Regex::Options.new(8))
      CRYSTAL
    end
    it "im" do
      assert_expand_regex_const %q(//im), <<-'CRYSTAL'
      ::Regex.new("", ::Regex::Options.new(7))
      CRYSTAL
    end
    it "imx" do
      assert_expand_regex_const %q(//imx), <<-'CRYSTAL'
      ::Regex.new("", ::Regex::Options.new(15))
      CRYSTAL
    end
  end
end
