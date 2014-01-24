#!/usr/bin/env bin/crystal --run
require "spec"

describe "Dir" do
  it "tests exists? on existing directory" do
    Dir.exists?(File.join([__DIR__, "../"])).should be_true
  end

  it "tests exists? on existing file" do
    Dir.exists?(__FILE__).should be_false
  end

  it "tests exists? on nonexistent directory" do
    Dir.exists?(File.join([__DIR__, "/foo/bar/"])).should be_false
  end
end
