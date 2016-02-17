require "../spec_helper"
require "tempfile"

describe "Compiler" do
  it "compiles a file" do
    tempfile = Tempfile.new "compiler_spec_output"
    tempfile.close

    Crystal::Command.run ["build", "#{__DIR__}/data/compiler_sample", "-o", tempfile.path]

    File.exists?(tempfile.path).should be_true

    `#{tempfile.path}`.should eq("Hello!")
  end

  it "runs subcommand in preference to a filename " do
    Dir.cd "#{__DIR__}/data/" do
      tempfile = Tempfile.new "compiler_spec_output"
      tempfile.close

      Crystal::Command.run ["build", "#{__DIR__}/data/compiler_sample", "-o", tempfile.path]

      File.exists?(tempfile.path).should be_true

      `#{tempfile.path}`.should eq("Hello!")
    end
  end
end
