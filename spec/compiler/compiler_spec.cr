require "../spec_helper"
require "./spec_helper"

describe "Compiler" do
  it "compiles a file" do
    with_tempfile "compiler_spec_output" do |path|
      Crystal::Command.run ["build", compiler_datapath("compiler_sample"), "-o", path]

      File.exists?(path).should be_true

      `#{path}`.should eq("Hello!")
    end
  end

  it "runs subcommand in preference to a filename " do
    Dir.cd compiler_datapath do
      with_tempfile "compiler_spec_output" do |path|
        Crystal::Command.run ["build", "compiler_sample", "-o", path]

        File.exists?(path).should be_true

        `#{path}`.should eq("Hello!")
      end
    end
  end
end
