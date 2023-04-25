require "../../spec_helper"

describe "Normalize: regex literal" do
  describe "options" do
    it "empty" do
      assert_expand %q(/#{"".to_s}/), <<-'CRYSTAL'
      ::Regex.new("#{"".to_s}", ::Regex::Options.new(0))
      CRYSTAL
    end
    it "i" do
      assert_expand %q(/#{"".to_s}/i), <<-'CRYSTAL'
      ::Regex.new("#{"".to_s}", ::Regex::Options.new(1))
      CRYSTAL
    end
    it "x" do
      assert_expand %q(/#{"".to_s}/x), <<-'CRYSTAL'
      ::Regex.new("#{"".to_s}", ::Regex::Options.new(8))
      CRYSTAL
    end
    it "im" do
      assert_expand %q(/#{"".to_s}/im), <<-'CRYSTAL'
      ::Regex.new("#{"".to_s}", ::Regex::Options.new(7))
      CRYSTAL
    end
    it "imx" do
      assert_expand %q(/#{"".to_s}/imx), <<-'CRYSTAL'
      ::Regex.new("#{"".to_s}", ::Regex::Options.new(15))
      CRYSTAL
    end
  end
end
