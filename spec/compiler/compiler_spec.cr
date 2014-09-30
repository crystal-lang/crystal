#!/usr/bin/env bin/crystal --run
require "../spec_helper"
require "tempfile"

describe "Compiler" do
  it "compiles a file" do
    tempfile = Tempfile.new "compiler_spec_output"
    tempfile.close

    compiler = Compiler.new
    compiler.process_options(["#{__DIR__}/data/compiler_sample", "-o", tempfile.path])

    File.exists?(tempfile.path).should be_true

    `#{tempfile.path}`.should eq("Hello!")
  end
end
