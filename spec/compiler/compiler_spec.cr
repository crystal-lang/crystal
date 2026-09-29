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

      Process.capture(path).should eq("Hello!")
    end
  end

  it "runs subcommand in preference to a filename " do
    Dir.cd compiler_datapath do
      with_temp_executable "compiler_spec_output" do |path|
        Crystal::Command.run ["build"].concat(program_flags_options).concat(["compiler_sample", "-o", path])

        File.exists?(path).should be_true

        Process.capture(path).should eq("Hello!")
      end
    end
  end

  it "cross-compiles with --emit=obj using a cold cache directory (#17506)" do
    with_cold_cache_dir do
      with_tempfile("cross_compile_source.cr") do |source_path|
        File.write(source_path, "")
        with_tempfile("cross_compile_output") do |output_path|
          Crystal::Command.run ["build", "--cross-compile", "--prelude=empty", "--emit=obj", "--no-color", "-o", output_path, source_path]

          # command.cr appends the object extension to `output_path`, and
          # that file is the emitted object
          objects = Dir.glob("#{output_path}*")
          objects.size.should eq(1)
          File.size(objects.first).should be > 0
        end
      end
    end
  end

  it "cross-compiles with --emit=llvm-bc using a cold cache directory (#17506)" do
    with_cold_cache_dir do
      with_tempfile("cross_compile_source.cr") do |source_path|
        File.write(source_path, "")
        with_tempfile("cross_compile_output") do |output_path|
          Crystal::Command.run ["build", "--cross-compile", "--prelude=empty", "--emit=llvm-bc", "--no-color", "-o", output_path, source_path]

          bitcode = Dir.glob("#{output_path}*.bc")
          bitcode.size.should eq(1)
          File.size(bitcode.first).should be > 0
        end
      end
    end
  end
end
