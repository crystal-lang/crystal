require "../spec_helper"
require "./spec_helper"

describe "Compiler" do
  it "has a valid version" do
    SemanticVersion.parse(Crystal::Config.version)
  end

  it "compiles a file" do
    with_temp_executable "compiler_spec_output" do |path|
      Crystal::Command.run ["build"].concat(program_flags_options).concat([compiler_datapath("compiler_sample"), "-o", path])

      File.exists?(path).should be_true

      `#{Process.quote(path)}`.should eq("Hello!")
    end
  end

  it "runs subcommand in preference to a filename " do
    Dir.cd compiler_datapath do
      with_temp_executable "compiler_spec_output" do |path|
        Crystal::Command.run ["build"].concat(program_flags_options).concat(["compiler_sample", "-o", path])

        File.exists?(path).should be_true

        `#{Process.quote(path)}`.should eq("Hello!")
      end
    end
  end

  it "treats all arguments post-filename as program arguments" do
    with_tempfile "args_test" do |path|
      Process.run(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "bin/crystal", [File.join(compiler_datapath, "args_test"), "-Dother_flag", "--", "bar", path])

      File.read(path).should eq(<<-FILE)
        ["-Dother_flag", "--", "bar"]
        {other_flag: false}
        FILE
    end
  end
end
