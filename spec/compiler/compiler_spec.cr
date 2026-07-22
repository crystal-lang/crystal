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

  it "reports codegen timings with parallel compilation" do
    compiler = create_spec_compiler
    compiler.n_threads = 2
    compiler.prelude = "empty"
    compiler.progress_tracker.stats = true
    output = IO::Memory.new
    compiler.stdout = output

    sources = [Compiler::Source.new("codegen_stats.cr", <<-CRYSTAL)]
      class Foo
        def value
          1
        end
      end

      class Bar
        def value
          2
        end
      end

      Foo.new.value + Bar.new.value
      CRYSTAL

    with_temp_executable "compiler_spec_output" do |path|
      compiler.compile(sources, path)
    end

    output.to_s.should contain("Top 10 slowest modules:")
    output.to_s.should contain("Foo")
    output.to_s.should contain("Bar")
  end
end
