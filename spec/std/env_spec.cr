require "spec"

describe "ENV" do
  it "gets non existent key raises" do
    expect_raises KeyError, "Missing ENV key: \"NON-EXISTENT\"" do
      ENV["NON-EXISTENT"]
    end
  end

  it "gets non existent key as nilable" do
    ENV["NON-EXISTENT"]?.should be_nil
  end

  it "set and gets" do
    (ENV["FOO"] = "1").should eq("1")
    ENV["FOO"].should eq("1")
    ENV["FOO"]?.should eq("1")
  end

  it "does has_key?" do
    ENV["FOO"] = "1"
    ENV.has_key?("BAR").should be_false
    ENV.has_key?("FOO").should be_true
  end

  it "deletes a key" do
    ENV["FOO"] = "1"
    ENV.delete("FOO").should eq("1")
    ENV.delete("FOO").should be_nil
    ENV.has_key?("FOO").should be_false
  end

  it "does .keys" do
    %w(FOO BAR).each { |k| ENV.keys.should_not contain(k) }
    ENV["FOO"] = ENV["BAR"] = "1"
    %w(FOO BAR).each { |k| ENV.keys.should contain(k) }
  end

  it "does .values" do
    [1, 2].each { |i| ENV.values.should_not contain("SOMEVALUE_#{i}") }
    ENV["FOO"] = "SOMEVALUE_1"
    ENV["BAR"] = "SOMEVALUE_2"
    [1, 2].each { |i| ENV.values.should contain("SOMEVALUE_#{i}") }
  end

  describe "fetch" do
    it "fetches with one argument" do
      ENV["1"] = "2"
      ENV.fetch("1").should eq("2")
    end

    it "fetches with default value" do
      ENV["1"] = "2"
      ENV.fetch("1", "3").should eq("2")
      ENV.fetch("2", "3").should eq("3")
    end

    it "fetches with block" do
      ENV["1"] = "2"
      ENV.fetch("1") { |k| k + "block" }.should eq("2")
      ENV.fetch("2") { |k| k + "block" }.should eq("2block")
    end

    it "fetches and raises" do
      ENV["1"] = "2"
      expect_raises KeyError, "Missing ENV key: \"2\"" do
        ENV.fetch("2")
      end
    end
  end
end
