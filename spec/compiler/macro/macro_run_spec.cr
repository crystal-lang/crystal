require "../../spec_helper"

describe "Crystal::Program#macro_run" do
  it "compiles a macro run program again when its cache directory was removed, or removed and created empty" do
    with_tempfile("macro_run.cr") do |filename|
      File.write(filename, "print ARGV[0]")
      program_dir = CacheDir.instance.directory_for(filename)
      program = Program.new
      program.macro_run(filename, ["first"]).stdout.should eq("first")

      # As a cleanup in another compiler process does
      FileUtils.rm_rf(program_dir)
      program.macro_run(filename, ["second"]).stdout.should eq("second")

      # As another compiler process does that starts to use the program
      FileUtils.rm_rf(program_dir)
      Dir.mkdir(program_dir)
      program.macro_run(filename, ["third"]).stdout.should eq("third")
    end
  end
end
